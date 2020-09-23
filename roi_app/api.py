from rest_framework import viewsets, permissions
from .serializers import LeadSerializer
from .models import LeadModel


class LeadApi(viewsets.ModelViewSet):
    queryset = LeadModel.objects.all()
    serializer_class = LeadSerializer
    permission_classes = [permissions.IsAuthenticated]