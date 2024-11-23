from fastapi import FastAPI, HTTPException, Depends
from fastapi.security import OAuth2PasswordRequestForm
from typing import Optional
from pydantic import BaseModel
from datetime import datetime, timedelta, timezone
from prometheus_client import make_asgi_app
from common.middleware import MetricsMiddleware
from prometheus_client import Counter, Histogram

class TokenResponse(BaseModel):
    access_token: str
    token_type: str
    expires_at: datetime

app = FastAPI()
metrics_middleware = MetricsMiddleware(app_name="auth-service")
app.add_middleware(metrics_middleware.__class__, app_name="auth-service")

metrics_app = make_asgi_app()
app.mount("/metrics", metrics_app)

@app.post("/token", response_model=TokenResponse)
async def login(form_data: OAuth2PasswordRequestForm = Depends()):
    if form_data.username != "test" or form_data.password != "test":
        raise HTTPException(status_code=401)
        
    return TokenResponse(
        access_token="sample_token",
        token_type="bearer",
        expires_at=datetime.now(timezone.utc) + timedelta(hours=1)
    )

@app.get("/health")
async def health_check():
    return {"status": "healthy", "service": "account"}