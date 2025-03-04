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
    account_id = Column(String(36), primary_key=True, index=True)
    customer_id = Column(String(50), nullable=False)
    account_type = Column(String(20), nullable=False)
    currency = Column(String(3), nullable=False)
    balance = Column(Float, nullable=False)
    created_at = Column(DateTime, default=datetime.now(timezone.utc))
    status = Column(String(10), default="ACTIVE")

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
async def render_account_form():
    """Render an HTML form to collect account details."""
    return """
    <!DOCTYPE html>
    <html>
    <head>
        <title>Create Account</title>
        <style>
            body {
                font-family: Arial, sans-serif;
                margin: 0;
                padding: 20px;
                background-color: #f4f4f4;
            }
            form {
                background: #ffffff;
                padding: 20px;
                border-radius: 8px;
                box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
                max-width: 400px;
                margin: auto;
            }
            input, select, button {
                display: block;
                width: 100%;
                margin-bottom: 15px;
                padding: 10px;
                border-radius: 4px;
                border: 1px solid #ccc;
            }
            button {
                background-color: #28a745;
                color: white;
                font-size: 16px;
                border: none;
                cursor: pointer;
            }
            button:hover {
                background-color: #218838;
            }
        </style>
    </head>
    <body>
        <h1>Create a New Account</h1>
        <form action="/accounts" method="post">
            <label for="customer_id">Customer ID:</label>
            <input type="text" id="customer_id" name="customer_id" required>

            <label for="account_type">Account Type:</label>
            <select id="account_type" name="account_type" required>
                <option value="savings">Savings</option>
                <option value="current">Current</option>
                <option value="business">Business</option>
            </select>

            <label for="currency">Currency:</label>
            <select id="currency" name="currency" required>
                <option value="USD">USD</option>
                <option value="EUR">EUR</option>
                <option value="INR">INR</option>
            </select>

            <label for="balance">Balance:</label>
            <input type="number" id="balance" name="balance" step="0.01" required>

            <button type="submit">Create Account</button>
        </form>
    </body>
    </html>
    """

@app.post("/accounts", response_class=HTMLResponse)
async def create_account_via_form(
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
    return f"""
    <!DOCTYPE html>
    <html>
    <head>
        <title>Account Created</title>
    </head>
    <body>
        <h1>Account Created Successfully!</h1>
        <p><strong>Customer ID:</strong> {customer_id}</p>
        <p><strong>Status:</strong> {account_data.status}</p>
        <a href="/accounts">Create Another Account</a>
    </body>
    </html>
    """


# HTML Form to collect `customer_id`
@app.get("/account-details", response_class=HTMLResponse)
async def render_customer_id_form():
    """Render an HTML form to collect customer_id."""
    return """
    <!DOCTYPE html>
    <html>
    <head>
        <title>Account Details</title>
        <style>
            body { font-family: Arial, sans-serif; background-color: #f4f4f4; margin: 0; padding: 20px; }
            form { background: #fff; padding: 20px; border-radius: 5px; max-width: 400px; margin: auto; box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1); }
            label, input { display: block; width: 100%; margin-bottom: 10px; }
            input { padding: 10px; font-size: 14px; border: 1px solid #ccc; border-radius: 3px; }
            button { background: #007bff; color: white; padding: 10px; border: none; border-radius: 3px; cursor: pointer; }
            button:hover { background: #0056b3; }
        </style>
    </head>
    <body>
        <h1>Search Account by Customer ID</h1>
        <form action="/account-details" method="post">
            <label for="customer_id">Customer ID:</label>
            <input type="text" id="customer_id" name="customer_id" required>
            <button type="submit">Search</button>
        </form>
    </body>
    </html>
    """

# Fetch and display account details based on `customer_id`
@app.post("/account-details", response_class=HTMLResponse)
async def get_account_details(customer_id: str = Form(...), db=Depends(get_db)):
    """Fetch and display account details for a given customer_id."""
    # Query the database for the provided customer_id
    accounts = db.query(AccountModel).filter(AccountModel.customer_id == customer_id).all()

    if not accounts:
        return HTMLResponse(content=f"""
        <!DOCTYPE html>
        <html>
        <head>
            <title>No Accounts Found</title>
        </head>
        <body>
            <h1>No Accounts Found</h1>
            <p>No account details found for the provided Customer ID: {customer_id}</p>
            <a href="/account-details">Search Again</a>
        </body>
        </html>
        """)

    # Use raw string for HTML to avoid `format()` conflicts
    html_content = f"""
    <!DOCTYPE html>
    <html>
    <head>
        <title>Account Details</title>
        <style>
            body {{
                font-family: Arial, sans-serif;
                background-color: #f4f4f4;
                margin: 0;
                padding: 20px;
            }}
            table {{
                width: 100%;
                border-collapse: collapse;
                background: #fff;
                margin: 20px 0;
                box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
            }}
            th, td {{
                border: 1px solid #ddd;
                padding: 12px;
                text-align: left;
            }}
            th {{
                background-color: #007bff;
                color: white;
            }}
            tr:nth-child(even) {{
                background-color: #f9f9f9;
            }}
            tr:hover {{
                background-color: #f1f1f1;
            }}
        </style>
    </head>
    <body>
        <h1>Account Details for Customer ID: {customer_id}</h1>
        <table>
            <thead>
                <tr>
                    <th>Account ID</th>
                    <th>Customer ID</th>
                    <th>Account Type</th>
                    <th>Currency</th>
                    <th>Balance</th>
                    <th>Created At</th>
                    <th>Status</th>
                </tr>
            </thead>
            <tbody>
    """

    for account in accounts:
        html_content += f"""
            <tr>
                <td>{account.account_id}</td>
                <td>{account.customer_id}</td>
                <td>{account.account_type}</td>
                <td>{account.currency}</td>
                <td>{account.balance}</td>
                <td>{account.created_at}</td>
                <td>{account.status}</td>
            </tr>
        """

    html_content += """
            </tbody>
        </table>
        <a href="/account-details">Search Another Customer</a>
    </body>
    </html>
    """

    return HTMLResponse(content=html_content)


@app.get("/health")
async def health_check():
    return {"status": "healthy", "service": "account"}
