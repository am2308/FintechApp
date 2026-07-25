from fastapi import Request
from starlette.middleware.base import BaseHTTPMiddleware
from prometheus_client import Counter, Histogram, Gauge
import time


class MetricsMiddleware(BaseHTTPMiddleware):
    def __init__(self, app, app_name: str):
        super().__init__(app)

        # Basic request metrics
        self.request_count = Counter(
            'http_requests_total',
            'Total HTTP requests',
            ['service', 'method', 'endpoint', 'status']
        )
        self.request_latency = Histogram(
            'http_request_duration_seconds',
            'HTTP request latency',
            ['service']
        )

        # Business metrics
        self.business_operations = Counter(
            'business_operations_total',
            'Business operation metrics',
            ['service', 'operation', 'status']
        )

        # Service health
        self.service_up = Gauge(
            'up',
            'Service up status',
            ['app']
        )

        self.app_name = app_name
        self.service_up.labels(app=self.app_name).set(1)

    async def dispatch(self, request: Request, call_next):
        start_time = time.time()

        try:
            response = await call_next(request)

            # Record request metrics
            duration = time.time() - start_time
            self.request_count.labels(
                service=self.app_name,
                method=request.method,
                endpoint=request.url.path,
                status=response.status_code
            ).inc()
            self.request_latency.labels(
                service=self.app_name
            ).observe(duration)

            # Record business metrics based on endpoint and status
            if request.url.path == "/accounts" and self.app_name == "account-service":
                self.business_operations.labels(
                    service=self.app_name,
                    operation="account_creation",
                    status="success" if response.status_code < 400 else "failure"
                ).inc()
            elif request.url.path == "/token" and self.app_name == "auth-service":
                self.business_operations.labels(
                    service=self.app_name,
                    operation="authentication",
                    status="success" if response.status_code < 400 else "failure"
                ).inc()
            elif request.url.path == "/transactions" and self.app_name == "transaction-service":
                self.business_operations.labels(
                    service=self.app_name,
                    operation="transaction",
                    status="success" if response.status_code < 400 else "failure"
                ).inc()

            return response

        except Exception as e:
            self.service_up.labels(app=self.app_name).set(0)
            raise e
