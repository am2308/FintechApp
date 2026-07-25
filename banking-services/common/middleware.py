# Drop-in replacement for your existing middleware.py
# Key upgrades:
#  1. Explicit histogram buckets tuned for fintech SLOs
#  2. Separate http_errors_total counter (4xx + 5xx split)
#  3. In-flight gauge (saturation signal)
#  4. slot + version labels from env vars (injected by Docker Compose / Helm)
#  5. Path normalisation: /accounts/uuid → /accounts/{id} (prevents cardinality explosion)

from fastapi import Request
from starlette.middleware.base import BaseHTTPMiddleware
from prometheus_client import Counter, Histogram, Gauge, Info
import time, os, re

# ── Latency buckets aligned to fintech SLOs ──────────────────────────────────
# <50ms = fast, <200ms = good, <500ms = acceptable, >500ms = SLO risk
# These are what histogram_quantile(0.95, ...) uses for p95 calculation
LATENCY_BUCKETS = (
    0.010, 0.025, 0.050, 0.100, 0.200,
    0.500, 1.0, 2.5, 5.0, 10.0
)

SKIP_PATHS = {"/metrics", "/health", "/healthz", "/ready", "/favicon.ico"}
UUID_PATTERN = re.compile(r'/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}')
NUM_PATTERN   = re.compile(r'/\d+')


class MetricsMiddleware(BaseHTTPMiddleware):
    def __init__(self, app, app_name: str):
        super().__init__(app)
        self.app_name = app_name
        slot    = os.getenv("SLOT", "local")     # blue | green | local
        version = os.getenv("APP_VERSION", "dev")

        # ── Counters ─────────────────────────────────────────────────────────
        self.req_total = Counter(
            'http_requests_total', 'Total HTTP requests',
            ['service', 'method', 'endpoint', 'status', 'status_class', 'slot']
        )
        self.err_total = Counter(
            'http_errors_total', 'HTTP 4xx and 5xx errors',
            ['service', 'method', 'endpoint', 'status', 'error_class', 'slot']
        )
        # ── Latency histogram ─────────────────────────────────────────────────
        self.latency = Histogram(
            'http_request_duration_seconds', 'HTTP request duration',
            ['service', 'method', 'endpoint', 'slot'],
            buckets=LATENCY_BUCKETS
        )
        # ── Gauges ───────────────────────────────────────────────────────────
        self.in_flight = Gauge(
            'http_requests_in_flight', 'Current in-flight requests', ['service', 'slot']
        )
        self.service_up = Gauge('up', 'Service up status', ['app', 'slot'])
        # ── Business KPI counter ──────────────────────────────────────────────
        self.biz_ops = Counter(
            'business_operations_total', 'Business operation counts',
            ['service', 'operation', 'status', 'slot']
        )
        # ── Service info ──────────────────────────────────────────────────────
        self.svc_info = Info('service_build', 'Service metadata')

        self.slot = slot
        self.service_up.labels(app=app_name, slot=slot).set(1)
        self.svc_info.info({'service': app_name, 'slot': slot, 'version': version})

    async def dispatch(self, request: Request, call_next):
        if request.url.path in SKIP_PATHS:
            return await call_next(request)

        endpoint = self._norm(request.url.path)
        self.in_flight.labels(service=self.app_name, slot=self.slot).inc()
        start = time.perf_counter()

        try:
            response = await call_next(request)
            dur = time.perf_counter() - start
            status = response.status_code
            cls = f"{status // 100}xx"

            self.req_total.labels(
                service=self.app_name, method=request.method,
                endpoint=endpoint, status=status, status_class=cls, slot=self.slot
            ).inc()

            if status >= 400:
                ec = "client_error" if status < 500 else "server_error"
                self.err_total.labels(
                    service=self.app_name, method=request.method,
                    endpoint=endpoint, status=status, error_class=ec, slot=self.slot
                ).inc()

            self.latency.labels(
                service=self.app_name, method=request.method,
                endpoint=endpoint, slot=self.slot
            ).observe(dur)

            self._biz(request.url.path, request.method, status)
            return response

        except Exception as e:
            self.service_up.labels(app=self.app_name, slot=self.slot).set(0)
            raise
        finally:
            self.in_flight.labels(service=self.app_name, slot=self.slot).dec()

    def _norm(self, path: str) -> str:
        path = UUID_PATTERN.sub('/{id}', path)
        path = NUM_PATTERN.sub('/{id}', path)
        return path

    def _biz(self, path: str, method: str, status: int):
        ops = {
            ("/accounts", "POST"): "account_creation",
            ("/token", "POST"): "authentication",
            ("/transactions", "POST"): "transaction",
        }
        op = ops.get((path, method))
        if op:
            self.biz_ops.labels(
                service=self.app_name, operation=op,
                status="success" if status < 400 else "failure",
                slot=self.slot
            ).inc()
