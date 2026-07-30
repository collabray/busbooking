import os
import logging
from celery import Celery
from typing import Optional, Dict

logger = logging.getLogger(__name__)

celery_app = Celery(
    "notification_service",
    broker=os.getenv("CELERY_BROKER_URL", "redis://localhost:6379/0"),
    backend=os.getenv("CELERY_RESULT_BACKEND", "redis://localhost:6379/0"),
)

celery_app.conf.update(
    task_serializer="json",
    accept_content=["json"],
    result_serializer="json",
    timezone="Africa/Nairobi",
    enable_utc=True,
    task_track_started=True,
    task_time_limit=300,
    worker_prefetch_multiplier=1,
)

@celery_app.task(bind=True, max_retries=3, default_retry_delay=60)
def send_notification(self, channel: str, recipient: str, title: str, body: str, data: Optional[Dict] = None):
    try:
        if channel == "push":
            return send_fcm_push(recipient, title, body, data or {})
        elif channel == "sms":
            return send_sms(recipient, body)
        elif channel == "whatsapp":
            return send_whatsapp(recipient, title, body)
        else:
            raise ValueError(f"Unknown channel: {channel}")
    except Exception as exc:
        logger.error(f"Notification failed: {exc}")
        raise self.retry(exc=exc)

def send_fcm_push(fcm_token: str, title: str, body: str, data: Dict):
    try:
        import firebase_admin
        from firebase_admin import messaging
        if not firebase_admin._apps:
            firebase_admin.initialize_app()

        message = messaging.Message(
            notification=messaging.Notification(title=title, body=body),
            data={k: str(v) for k, v in data.items()},
            token=fcm_token,
            android=messaging.AndroidConfig(priority="high"),
        )
        response = messaging.send(message)
        logger.info(f"FCM sent: {response}")
        return {"status": "sent", "message_id": response}
    except Exception as e:
        logger.error(f"FCM failed: {e}")
        raise

def send_sms(phone_number: str, message: str):
    try:
        import africastalking
        username = os.getenv("AT_USERNAME", "sandbox")
        api_key = os.getenv("AT_API_KEY")
        africastalking.initialize(username, api_key)
        sms = africastalking.SMS
        response = sms.send(message, [phone_number])
        logger.info(f"SMS sent: {response}")
        return {"status": "sent", "response": response}
    except Exception as e:
        logger.error(f"SMS failed: {e}")
        raise

def send_whatsapp(phone_number: str, title: str, body: str):
    try:
        from twilio.rest import Client
        account_sid = os.getenv("TWILIO_ACCOUNT_SID")
        auth_token = os.getenv("TWILIO_AUTH_TOKEN")
        from_number = os.getenv("TWILIO_WHATSAPP_NUMBER")

        client = Client(account_sid, auth_token)
        message = client.messages.create(
            from_=f"whatsapp:{from_number}",
            body=f"*{title}*\n\n{body}",
            to=f"whatsapp:{phone_number}"
        )
        logger.info(f"WhatsApp sent: {message.sid}")
        return {"status": "sent", "message_sid": message.sid}
    except Exception as e:
        logger.error(f"WhatsApp failed: {e}")
        raise
