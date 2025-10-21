from fastapi import FastAPI, HTTPException
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from datetime import datetime, timezone
import httpx
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(
    title="HNG DevOps API",
    description="Stage 0 FastAPI Application with Cat Facts",
    version="1.0.0"
)

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Allows all origins
    allow_credentials=True,
    allow_methods=["*"],  # Allows all methods
    allow_headers=["*"],  # Allows all headers
)

# Configuration
CAT_FACTS_API_URL = "https://catfact.ninja/fact"
REQUEST_TIMEOUT = 5  # seconds

USER_EMAIL = "gitauwairimu@gmail.com"  
USER_NAME = "Charles Gitau Wairimu"
USER_STACK = "Python/FastAPI"

async def fetch_cat_fact() -> str:
    """
    Fetch a random cat fact from the Cat Facts API
    Returns a fallback message if the API fails
    """
    try:
        async with httpx.AsyncClient(timeout=REQUEST_TIMEOUT) as client:
            response = await client.get(CAT_FACTS_API_URL)
            
            if response.status_code == 200:
                data = response.json()
                return data.get("fact", "No fact available")
            else:
                logger.warning(f"Cat Facts API returned status {response.status_code}")
                return "Unable to fetch cat fact at this time"
                
    except httpx.TimeoutException:
        logger.error("Cat Facts API request timed out")
        return "Cat fact service is currently unavailable"
    except httpx.RequestError as e:
        logger.error(f"Error fetching cat fact: {str(e)}")
        return "Failed to fetch cat fact due to network error"
    except Exception as e:
        logger.error(f"Unexpected error: {str(e)}")
        return "An unexpected error occurred while fetching cat fact"

def get_current_timestamp() -> str:
    """Get current UTC time in ISO 8601 format"""
    return datetime.now(timezone.utc).isoformat().replace('+00:00', 'Z')



@app.get("/")
async def root():
    """
    Simple root endpoint
    """
    return {"message": "HNG DevOps API is running", "status": "healthy"}



@app.get("/me", response_class=JSONResponse)
async def get_me():
    """
    Endpoint that returns user information in the exact JSON format required
    """
    try:
        # Fetch cat fact asynchronously
        cat_fact = await fetch_cat_fact()
        
        # Prepare response data
        response_data = {
            "status": "success",
            "user": {
                "email": USER_EMAIL,
                "name": USER_NAME,
                "stack": USER_STACK
            },
            "timestamp": get_current_timestamp(),
            "fact": cat_fact
        }
        
        logger.info(f"Successfully processed request at {response_data['timestamp']}")
        
        return JSONResponse(
            content=response_data,
            media_type="application/json"
        )
        
    except Exception as e:
        logger.error(f"Error in /me endpoint: {str(e)}")
        raise HTTPException(
            status_code=500,
            detail="Internal server error"
        )

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        app,
        host="0.0.0.0",
        port=8000,
        log_level="info"
    )