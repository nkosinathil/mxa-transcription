# MXA Transcription - System Architecture

## Overview

MXA Transcription is a distributed web application for audio transcription with speaker diarization. The system is deployed across three physical servers with distinct responsibilities.

## Server Architecture

### Server 1: PHP Frontend (192.168.1.66)
**Purpose**: User interface and session management

**Components**:
- Apache web server
- PHP 8.x application
- PostgreSQL 14+ database
- Keycloak OIDC client integration

**Responsibilities**:
- User authentication via Keycloak SSO
- File upload interface
- Job submission and tracking
- Transcript viewing and management
- Role-based access control (RBAC)

### Server 2: Python Processing Backend (192.168.1.90)
**Purpose**: Audio processing and storage

**Components**:
- FastAPI REST API
- Celery distributed task queue
- Redis (Celery broker/backend)
- MinIO object storage
- Faster-Whisper transcription engine
- Pyannote.audio speaker diarization

**Responsibilities**:
- Audio file storage in MinIO
- Asynchronous transcription processing
- Speaker diarization
- Language detection
- Transcript generation (JSON, TXT)
- API for job status and results retrieval

### Server 3: Identity Provider (192.168.1.59)
**Purpose**: Centralized authentication

**Components**:
- Keycloak SSO server

**Responsibilities**:
- User authentication (OIDC/OAuth2)
- User management
- Role assignment
- Token issuance and validation

## Data Flow

### 1. Upload Workflow
```
User (Browser)
  → PHP Frontend (192.168.1.66)
    → Authenticates with Keycloak (192.168.1.59)
    → Uploads audio file
    → PHP creates job record in PostgreSQL
    → PHP sends file to Python API (192.168.1.90)
      → FastAPI stores file in MinIO
      → FastAPI queues Celery task
      → Returns job_id to PHP
    → PHP redirects to job status page
```

### 2. Processing Workflow
```
Celery Worker (192.168.1.90)
  → Picks up transcription task from Redis queue
  → Downloads audio from MinIO
  → Runs Faster-Whisper (language detection + transcription)
  → Runs Pyannote.audio (speaker diarization)
  → Combines results (speaker-labeled transcript)
  → Stores outputs in MinIO
  → Updates job status in PostgreSQL (via API call to PHP)
  → Sends completion notification
```

### 3. Retrieval Workflow
```
User (Browser)
  → PHP Frontend (192.168.1.66)
    → Requests transcript view
    → PHP queries PostgreSQL for job details
    → PHP calls Python API for transcript content
      → FastAPI retrieves from MinIO
      → Returns JSON/TXT transcript
    → PHP renders transcript with speaker labels
```

## Security Model

### Authentication
- **Keycloak OIDC**: All users authenticate through Keycloak
- **Session Management**: PHP maintains user sessions after OIDC login
- **API Authentication**: Internal API calls use shared secret (X-Api-Key header)

### Authorization
- **Roles**: user, admin, operator
- **Permissions**: 
  - `user`: Upload files, view own transcripts
  - `operator`: View all transcripts, manage jobs
  - `admin`: Full system access, user management

### Network Security
- **Internal Network**: All 3 servers on 192.168.1.0/24 private subnet
- **CSRF Protection**: All PHP forms include CSRF tokens
- **Input Validation**: File type and size validation
- **SQL Injection Prevention**: Prepared statements only

## Storage

### PostgreSQL Database Schema
```sql
-- Core tables
users (id, username, email, keycloak_id, roles, created_at)
jobs (id, user_id, status, filename, file_size, language, duration, created_at, updated_at)
transcripts (id, job_id, format, content, speaker_count, created_at)
audit_logs (id, user_id, action, resource, ip_address, timestamp)
```

### MinIO Object Storage
```
Buckets:
  - audio-uploads/     # Original audio files
  - transcripts/       # Generated transcripts (JSON, TXT)
  - temp/              # Temporary processing files
```

### Redis Data Structures
```
Queues:
  - celery:tasks       # Pending tasks
  - celery:results     # Task results

Keys:
  - job:{job_id}       # Job status cache
  - rate_limit:{user_id}  # Rate limiting
```

## Technology Stack

### Frontend (PHP)
- PHP 8.1+
- Composer (dependency management)
- Keycloak PHP Adapter
- PostgreSQL PDO driver
- Custom MVC framework

### Backend (Python)
- Python 3.10+
- FastAPI (REST API)
- Celery (task queue)
- Faster-Whisper (transcription)
- Pyannote.audio (diarization)
- MinIO Python SDK
- Redis Python client
- SQLAlchemy (ORM)

### Infrastructure
- Apache 2.4
- PostgreSQL 14
- Redis 7
- MinIO (latest)
- Keycloak 21+

## Scalability Considerations

### Horizontal Scaling
- **Celery Workers**: Add more workers on Server 2 or additional servers
- **PHP Instances**: Add more Apache workers or load-balanced servers
- **MinIO**: Can be clustered across multiple nodes

### Vertical Scaling
- **Server 2**: GPU acceleration for Whisper (CUDA)
- **PostgreSQL**: Connection pooling, query optimization
- **Redis**: Increase memory allocation

## Monitoring & Logging

### Application Logs
- **PHP**: `/var/www/html/php-app/storage/logs/app.log`
- **FastAPI**: `/var/log/transcription-api/api.log`
- **Celery**: `/var/log/transcription-api/celery.log`

### System Metrics
- **Job throughput**: Transcriptions per hour
- **Queue depth**: Pending jobs in Redis
- **Processing time**: Average time per file
- **Error rate**: Failed jobs percentage
- **Storage usage**: MinIO bucket sizes

## Deployment Architecture

Each server has independent deployment:
- Server 1: `deploy/php-server/`
- Server 2: `deploy/python-server/`
- Server 3: `deploy/keycloak-server/`

See individual deployment guides in each directory.

## Network Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    192.168.1.0/24 Network                   │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────────────┐      ┌──────────────────┐           │
│  │  Keycloak SSO    │◄─────┤   User Browser   │           │
│  │  192.168.1.59    │      └──────────────────┘           │
│  └────────┬─────────┘              │                       │
│           │                        │                       │
│           │ (OIDC)                 │ (HTTPS)              │
│           │                        ▼                       │
│           │            ┌──────────────────────┐           │
│           └───────────►│   PHP Frontend       │           │
│                        │   192.168.1.66       │           │
│                        │   - Apache           │           │
│                        │   - PostgreSQL       │           │
│                        └──────────┬───────────┘           │
│                                   │                        │
│                                   │ (Internal API)        │
│                                   ▼                        │
│                        ┌──────────────────────┐           │
│                        │  Python Backend      │           │
│                        │  192.168.1.90        │           │
│                        │  - FastAPI           │           │
│                        │  - Celery + Redis    │           │
│                        │  - MinIO Storage     │           │
│                        │  - Whisper + Pyannote│           │
│                        └──────────────────────┘           │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## Development vs Production

### Development Environment
- Single server can run all components
- Use Docker Compose for local development
- SQLite for quick testing (not recommended for production)

### Production Environment
- 3 dedicated servers as specified
- TLS/SSL certificates for all HTTPS endpoints
- Firewall rules limiting server-to-server communication
- Regular backups of PostgreSQL and MinIO data
- Log rotation and monitoring

## Future Enhancements

1. **Real-time Updates**: WebSocket support for live progress
2. **Batch Processing**: Upload multiple files at once
3. **Advanced Search**: Full-text search in transcripts
4. **Export Formats**: PDF, DOCX, SRT subtitle files
5. **Transcript Editing**: Manual correction interface
6. **API Access**: Public API for programmatic access
7. **Mobile App**: Native iOS/Android applications
