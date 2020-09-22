from django.db import models
import uuid


class LeadModel(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4())
    name = models.CharField(max_length=255, blank=True)
    phone = models.CharField(max_length=16, blank=True)
    document_number = models.CharField(max_length=14, blank=True)
    email = models.EmailField(max_length=255, unique=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.lead_model}"

