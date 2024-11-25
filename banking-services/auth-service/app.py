from fastapi import FastAPI, HTTPException, Depends
from fastapi.security import OAuth2PasswordBearer
from typing import List
from pydantic import BaseModel
from datetime import datetime, timezone
import uuid
import jwt  # Install with `pip install pyjwt`
from prometheus_client import make_asgi_app
from common.middleware import MetricsMiddleware
from sqlalchemy import create_engine, Column, String, Float, DateTime
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
import os
from fastapi.responses import HTMLResponse
from fastapi import Form

# Secret key (should be loaded from environment or secrets)
JWT_SECRET = "sample_secret"  # Same secret used in auth-service
ALGORITHM = "HS256"

# Database setup with environment variables
# Database setup with environment variables
MYSQL_USER = "root"
MYSQL_PASSWORD = os.getenv("MYSQL_ROOT_PASSWORD", "default_password")  # Replace 'default_password' with a safer default or empty string
MYSQL_HOST = os.getenv("MYSQL_HOST", "account-mysql")
MYSQL_PORT = 3306
MYSQL_DB = os.getenv("MYSQL_DB", "accounts_db")

DATABASE_URL = f"mysql+pymysql://{MYSQL_USER}:{MYSQL_PASSWORD}@{MYSQL_HOST}:{MYSQL_PORT}/{MYSQL_DB}"

engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

# Database model
class AccountModel(Base):
    __tablename__ = "accounts"
    account_id = Column(String, primary_key=True, index=True)
    customer_id = Column(String, nullable=False)
    account_type = Column(String, nullable=False)
    currency = Column(String, nullable=False)
    balance = Column(Float, nullable=False)
    created_at = Column(DateTime, default=datetime.now(timezone.utc))
    status = Column(String, default="ACTIVE")

# Create tables
Base.metadata.create_all(bind=engine)

# Pydantic models
class AccountBase(BaseModel):
    customer_id: str
    account_type: str
    currency: str
    balance: float

class AccountResponse(AccountBase):
    account_id: str
    created_at: datetime
    status: str

app = FastAPI()

app.add_middleware(MetricsMiddleware, app_name="auth-service")

metrics_app = make_asgi_app()
app.mount("/metrics", metrics_app)

#oauth2_scheme = OAuth2PasswordBearer(tokenUrl="token")

# Dependency for DB session
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

@app.get("/authenticate/{customer_id}")
async def authenticate_customer(customer_id: str, db=Depends(get_db)):
    # Check if customer_id exists in the accounts table
    account = db.query(AccountModel).filter(AccountModel.customer_id == customer_id).first()
    
    if account:
        return {"message": f"Customer ID {customer_id} authenticated successfully."}
    else:
        raise HTTPException(status_code=404, detail=f"Customer ID {customer_id} not found in accounts.")

@app.get("/health")
async def health_check():
    return {"status": "healthy", "service": "account"}
