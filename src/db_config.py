"""Database connection helper.

Reads connection settings from environment variables (see .env.example at the
repo root). Copy that file to `.env` and adjust it for your local MySQL setup
before running any of the scripts in this folder.
"""

import os

import mysql.connector
from dotenv import load_dotenv

load_dotenv()


def get_connection():
    """Open a new connection to the medicine_shortage_tracker database."""
    return mysql.connector.connect(
        host=os.getenv("DB_HOST", "localhost"),
        port=int(os.getenv("DB_PORT", "3306")),
        user=os.getenv("DB_USER", "root"),
        password=os.getenv("DB_PASSWORD", ""),
        database=os.getenv("DB_NAME", "medicine_shortage_tracker"),
    )
