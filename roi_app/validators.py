from rest_framework import serializers
from .models import LeadModel


class LeadIdValidator:
    def __call__(self, lead_id):
        if not LeadModel.objects.filter(pk=lead_id).exists():
            raise serializers.ValidationError(f"Invalid pk {lead_id} - object does not exist...")