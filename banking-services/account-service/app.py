from fastapi import FastAPI, HTTPException, Depends
from fastapi.security import OAuth2PasswordBearer
from typing import Optional
from pydantic import BaseModel
from datetime import datetime, timezone
import uuid
from prometheus_client import make_asgi_app
from common.middleware import MetricsMiddleware
from prometheus_client import Counter, Histogram

class AccountBase(BaseModel):
    customer_id: str
    account_type: str
    currency: str
    balance: float

class AccountResponse(AccountBase):
    account_id: str
    created_at: datetime
    status: str
'''
app = FastAPI()

metrics_middleware = MetricsMiddleware(app_name="account-service")
app.add_middleware(metrics_middleware.__class__, app_name="account-service")

metrics_app = make_asgi_app()
app.mount("/metrics", metrics_app)
'''
app = FastAPI()

# Add the middleware with app_name="auth-service"
app.add_middleware(MetricsMiddleware, app=app, app_name="auth-service")

# Mount the Prometheus metrics endpoint
metrics_app = make_asgi_app()
app.mount("/metrics", metrics_app)

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="token")

@app.post("/accounts/", response_model=AccountResponse)
async def create_account(account: AccountBase):
    account_id = str(uuid.uuid4())
    return AccountResponse(
        account_id=account_id,
        created_at=datetime.now(timezone.utc),
        status="ACTIVE",
        **account.model_dump()
    )

@app.get("/health")
async def health_check():
    return {"status": "healthy", "service": "account"}
