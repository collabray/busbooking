import asyncio
from contextlib import asynccontextmanager
from fastapi import FastAPI, BackgroundTasks
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field
from typing import List, Optional
import redis.asyncio as redis
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST
from fastapi.responses import Response
import logging

from app.tasks import send_notification

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

NOTIFICATIONS_SENT = Counter('notifications_sent_total', 'Total notifications sent', ['channel', 'status'])
NOTIFICATION_LATENCY = Histogram('notification_latency_seconds', 'Notification latency')

redis_client = redis.Redis(host='localhost', port=6379, db=0, decode_responses=True)

@asynccontextmanager
async def lifespan(app: FastAPI):
    await redis_client.ping()
    logger.info("Notification Service started")
    yield
    await redis_client.close()

app = FastAPI(title="OmniBus Notification Engine", version="1.0.0", lifespan=lifespan)

class NotificationRequest(BaseModel):
    user_id: str = Field(..., min_length=1)
    channels: List[str] = Field(..., min_items=1)  # push, sms, whatsapp, email
    title: str = Field(..., min_length=1, max_length=200)
    body: str = Field(..., min_length=1, max_length=1000)
    data: Optional[dict] = Field(default_factory=dict)
    priority: str = Field(default="normal", pattern="^(normal|high|critical)$")
    phone_number: Optional[str] = None
    fcm_token: Optional[str] = None

@app.get("/health")
async def health():
    return {"status": "healthy", "service": "notification-service"}

@app.get("/metrics")
async def metrics():
    return Response(content=generate_latest(), media_type=CONTENT_TYPE_LATEST)

@app.post("/api/v1/notify")
async def send_notify(request: NotificationRequest, background_tasks: BackgroundTasks):
    background_tasks.add_task(process_notification, request)
    return JSONResponse(
        status_code=202,
        content={"message": "Notification queued", "notification_id": request.user_id + "_" + str(asyncio.get_event_loop().time())}
    )

@app.post("/api/v1/notify/sync")
async def send_notify_sync(request: NotificationRequest):
    result = await process_notification(request)
    return result

async def process_notification(request: NotificationRequest):
    results = {}
    for channel in request.channels:
        try:
            if channel == "push" and request.fcm_token:
                task = send_notification.delay("push", request.fcm_token, request.title, request.body, request.data)
                results["push"] = {"status": "queued", "task_id": task.id}
                NOTIFICATIONS_SENT.labels(channel="push", status="queued").inc()
            elif channel == "sms" and request.phone_number:
                task = send_notification.delay("sms", request.phone_number, request.title, request.body)
                results["sms"] = {"status": "queued", "task_id": task.id}
                NOTIFICATIONS_SENT.labels(channel="sms", status="queued").inc()
            elif channel == "whatsapp" and request.phone_number:
                task = send_notification.delay("whatsapp", request.phone_number, request.title, request.body)
                results["whatsapp"] = {"status": "queued", "task_id": task.id}
                NOTIFICATIONS_SENT.labels(channel="whatsapp", status="queued").inc()
            else:
                results[channel] = {"status": "skipped", "reason": "missing required field"}
                NOTIFICATIONS_SENT.labels(channel=channel, status="skipped").inc()
        except Exception as e:
            logger.error(f"Failed to queue {channel}: {e}")
            results[channel] = {"status": "error", "error": str(e)}
            NOTIFICATIONS_SENT.labels(channel=channel, status="error").inc()
    return {"results": results}

@app.post("/api/v1/broadcast")
async def broadcast(request: NotificationRequest):
    # Broadcast to all users (admin only)
    return {"message": "Broadcast queued", "channels": request.channels}
