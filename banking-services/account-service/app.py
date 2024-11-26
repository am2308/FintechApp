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
from fastapi import FastAPI, Form, Depends, HTTPException
from fastapi.responses import HTMLResponse
from fastapi.templating import Jinja2Templates
from fastapi.requests import Request

# Secret key (should be loaded from environment or secrets)
JWT_SECRET = "sample_secret"  # Same secret used in auth-service
ALGORITHM = "HS256"

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
templates = Jinja2Templates(directory="templates")
app.add_middleware(MetricsMiddleware, app_name="account-service")

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


@app.get("/accounts", response_class=HTMLResponse)
async def render_account_form(request: Request):
    """Render an HTML form to collect account details."""
    return templates.TemplateResponse("create_account.html", {"request": request})

@app.post("/accounts", response_class=HTMLResponse)
async def create_account_via_form(
    request: Request,
    customer_id: str = Form(...),
    account_type: str = Form(...),
    currency: str = Form(...),
    balance: float = Form(...),
    db=Depends(get_db),
):
    """Handle form submission to create an account."""
    # Generate a unique account ID
    account_id = str(uuid.uuid4())
    account_data = AccountModel(
        account_id=account_id,
        customer_id=customer_id,
        account_type=account_type,
        currency=currency,
        balance=balance,
        created_at=datetime.now(timezone.utc),
        status="ACTIVE",
    )

    # Save to database
    db.add(account_data)
    db.commit()
    db.refresh(account_data)

    # Return success message
    return templates.TemplateResponse(
        "account_created.html",
        {
            "request": request,
            "customer_id": customer_id,
            "status": account_data.status,
        },
    )


# HTML Form to collect `customer_id`
@app.get("/account-details", response_class=HTMLResponse)
async def render_customer_id_form(request: Request):
    """Render an HTML form to collect customer_id."""
    return templates.TemplateResponse("search_account.html", {"request": request})

# Fetch and display account details based on `customer_id`
@app.post("/account-details", response_class=HTMLResponse)
async def get_account_details(request: Request, customer_id: str = Form(...), db=Depends(get_db)):
    """Fetch and display account details for a given customer_id."""
    # Query the database for the provided customer_id
    accounts = db.query(AccountModel).filter(AccountModel.customer_id == customer_id).all()

    if not accounts:
        return templates.TemplateResponse(
            "account_details.html",
            {"request": request, "accounts": None, "customer_id": customer_id},
        )

    # Use raw string for HTML to avoid `format()` conflicts
    return templates.TemplateResponse(
        "account_details.html",
        {"request": request, "accounts": accounts, "customer_id": customer_id},
    )


@app.get("/health")
async def health_check():
    return {"status": "healthy", "service": "account"}