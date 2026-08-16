import requests
import os
import logging
from dotenv import load_dotenv

logging.basicConfig(level=logging.INFO)
load_dotenv()

app_id = os.environ.get("A_CLIENT_ID")
app_secret = os.environ.get("A_CLIENT_SECRET")

app_b_id = os.environ.get("B_CLIENT_ID")
tenant_id = os.environ.get("ARM_TENANT_ID")

logging.info(f"App A ID: {app_id}, App B ID: {app_b_id}, Tenant ID: {tenant_id}")

# Step A: exchange client_id + secret for a token (client_credentials)
token_resp = requests.post(
    f"https://login.microsoftonline.com/{tenant_id}/oauth2/v2.0/token",
    data={
        "grant_type": "client_credentials",
        "client_id": app_id,
        "client_secret": app_secret,
        "scope": f"api://{app_b_id}/.default",
    },
).json()
logging.info(f"Token response: {token_resp}")
access_token = token_resp["access_token"]

# Step B: call API B with that token
headers = {"Authorization": f"Bearer {access_token}"}

