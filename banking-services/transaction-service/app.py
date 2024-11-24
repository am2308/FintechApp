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
from sqlalchemy import ForeignKey
from sqlalchemy.orm import relationship
import requests

# Database setup
# Database setup with environment variables
MYSQL_USER = "root"
MYSQL_PASSWORD = os.getenv("MYSQL_ROOT_PASSWORD", "default_password")  # Replace 'default_password' with a safer default or empty string
MYSQL_HOST = os.getenv("MYSQL_HOST", "account-mysql")
MYSQL_PORT = 3306
MYSQL_DB = os.getenv("MYSQL_DB", "accounts_db")
AUTH_HOST = os.getenv("AUTH_HOST", "auth-service")
AUTH_PORT = os.getenv("AUTH_PORT", 8082)

DATABASE_URL = f"mysql+pymysql://{MYSQL_USER}:{MYSQL_PASSWORD}@{MYSQL_HOST}:{MYSQL_PORT}/{MYSQL_DB}"

engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

# Database models
class AccountModel(Base):
    __tablename__ = "accounts"
    account_id = Column(String, primary_key=True, index=True)
    customer_id = Column(String, nullable=False)
    account_type = Column(String, nullable=False)
    currency = Column(String, nullable=False)
    balance = Column(Float, nullable=False)
    created_at = Column(DateTime, default=datetime.now(timezone.utc))
    status = Column(String, default="ACTIVE")

class TransactionModel(Base):
    __tablename__ = "transactions"
    transaction_id = Column(String, primary_key=True, index=True)
    account_id = Column(String, ForeignKey("accounts.account_id"), nullable=False)
    transaction_type = Column(String, nullable=False)  # 'credit' or 'debit'
    amount = Column(Float, nullable=False)
    created_at = Column(DateTime, default=datetime.now(timezone.utc))

    account = relationship("AccountModel", backref="transactions")

# Create tables
Base.metadata.create_all(bind=engine)

# FastAPI app setup
app = FastAPI()

app.add_middleware(MetricsMiddleware, app_name="account-service")

metrics_app = make_asgi_app()
app.mount("/metrics", metrics_app)

# Dependency for DB session
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

# HTML templates
def render_customer_form():
    return """
    <!DOCTYPE html>
    <html>
    <head>
        <title>Customer Authentication</title>
        <style>
            body { font-family: Arial, sans-serif; margin: 20px; }
            form { margin-bottom: 20px; }
        </style>
    </head>
    <body>
        <h1>Enter Customer ID</h1>
        <form action="/transaction" method="post">
            <label for="customer_id">Customer ID:</label>
            <input type="text" id="customer_id" name="customer_id" required>
            <button type="submit">Authenticate</button>
        </form>
    </body>
    </html>
    """

def render_transaction_form(customer_id):
    return f"""
    <!DOCTYPE html>
    <html>
    <head>
        <title>Transaction</title>
        <style>
            body {{ font-family: Arial, sans-serif; margin: 20px; }}
            form {{ margin-bottom: 20px; }}
        </style>
    </head>
    <body>
        <h1>Welcome, Customer {customer_id}</h1>
        <p>Authenticated successfully.</p>
        <form action="/transaction-process" method="post">
            <label for="transaction_type">Transaction Type:</label>
            <select id="transaction_type" name="transaction_type" required>
                <option value="credit">Credit</option>
                <option value="debit">Debit</option>
            </select><br><br>
            <label for="amount">Amount:</label>
            <input type="number" id="amount" name="amount" required><br><br>
            <input type="hidden" name="customer_id" value="{customer_id}">
            <button type="submit">Submit Transaction</button>
        </form>
    </body>
    </html>
    """

def render_account_details(account):
    return f"""
    <!DOCTYPE html>
    <html>
    <head>
        <title>Account Details</title>
        <style>
            body {{ font-family: Arial, sans-serif; margin: 20px; }}
            table {{ border-collapse: collapse; width: 100%; }}
            th, td {{ border: 1px solid black; padding: 8px; text-align: left; }}
            th {{ background-color: #f2f2f2; }}
        </style>
    </head>
    <body>
        <h1>Updated Account Details</h1>
        <table>
            <tr>
                <th>Account ID</th>
                <td>{account.account_id}</td>
            </tr>
            <tr>
                <th>Customer ID</th>
                <td>{account.customer_id}</td>
            </tr>
            <tr>
                <th>Account Type</th>
                <td>{account.account_type}</td>
            </tr>
            <tr>
                <th>Currency</th>
                <td>{account.currency}</td>
            </tr>
            <tr>
                <th>Balance</th>
                <td>{account.balance}</td>
            </tr>
            <tr>
                <th>Status</th>
                <td>{account.status}</td>
            </tr>
        </table>
        <a href="/transaction">New Transaction</a>
    </body>
    </html>
    """

@app.get("/transaction", response_class=HTMLResponse)
async def get_customer_form():
    return render_customer_form()

@app.post("/transaction", response_class=HTMLResponse)
async def authenticate_customer(customer_id: str = Form(...), db=Depends(get_db)):
    # Call auth-service for verification
    auth_url = f"http://{AUTH_HOST}:{AUTH_PORT}/authenticate/{customer_id}"
    response = requests.get(auth_url)

    if response.status_code == 200:
        # Check if the customer exists in the database
        account = db.query(AccountModel).filter(AccountModel.customer_id == customer_id).first()
        if not account:
            return HTMLResponse(content=f"<h1>Customer ID {customer_id} does not exist in the database.</h1>")
        return render_transaction_form(customer_id)
    else:
        return HTMLResponse(content=f"<h1>Authentication failed for Customer ID: {customer_id}</h1>")

@app.post("/transaction-process", response_class=HTMLResponse)
async def process_transaction(customer_id: str = Form(...), transaction_type: str = Form(...), amount: float = Form(...), db=Depends(get_db)):
    # Fetch account details
    account = db.query(AccountModel).filter(AccountModel.customer_id == customer_id).first()
    if not account:
        return HTMLResponse(content=f"<h1>Customer ID {customer_id} does not exist in the database.</h1>")

    # Perform transaction
    if transaction_type == "debit":
        if account.balance < amount:
            return HTMLResponse(content=f"<h1>Insufficient funds for debit transaction.</h1>")
        account.balance -= amount
    elif transaction_type == "credit":
        account.balance += amount

    # Update transaction table
    transaction = TransactionModel(
        transaction_id=str(uuid.uuid4()),
        account_id=account.account_id,
        transaction_type=transaction_type,
        amount=amount
    )
    db.add(transaction)
    db.commit()

    return render_account_details(account)

@app.get("/health")
async def health_check():
    return {"status": "healthy", "service": "account"}
