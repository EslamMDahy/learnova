enum MaterialKind { video, pdf, document, presentation, link, quiz }

enum MaterialProcessingStatus { draftUpload, uploaded, processing, ready, error }

MaterialKind parseMaterialKind(String? raw) {
  switch ((raw ?? '').trim().toLowerCase()) {
    case 'video':
      return MaterialKind.video;
    case 'document':
      return MaterialKind.document;
    case 'presentation':
      return MaterialKind.presentation;
    case 'link':
      return MaterialKind.link;
    case 'quiz':
      return MaterialKind.quiz;
    case 'pdf':
    default:
      return MaterialKind.pdf;
  }
}

MaterialProcessingStatus parseMaterialProcessingStatus(String? raw) {
  switch ((raw ?? '').trim().toLowerCase()) {
    case 'uploaded':
      return MaterialProcessingStatus.uploaded;
    case 'processing':
      return MaterialProcessingStatus.processing;
    case 'ready':
      return MaterialProcessingStatus.ready;
    case 'error':
      return MaterialProcessingStatus.error;
    case 'draft_upload':
    default:
      return MaterialProcessingStatus.draftUpload;
  }
}

extension MaterialKindBackend on MaterialKind {
  String get backendValue {
    switch (this) {
      case MaterialKind.video:
        return 'video';
      case MaterialKind.pdf:
        return 'pdf';
      case MaterialKind.document:
        return 'document';
      case MaterialKind.presentation:
        return 'presentation';
      case MaterialKind.link:
        return 'link';
      case MaterialKind.quiz:
        return 'quiz';
    }
  }

  String get label {
    switch (this) {
      case MaterialKind.video:
        return 'Video';
      case MaterialKind.pdf:
        return 'PDF';
      case MaterialKind.document:
        return 'Document';
      case MaterialKind.presentation:
        return 'Presentation';
      case MaterialKind.link:
        return 'Link';
      case MaterialKind.quiz:
        return 'Quiz';
    }
  }
}

extension MaterialProcessingStatusBackend on MaterialProcessingStatus {
  String get backendValue {
    switch (this) {
      case MaterialProcessingStatus.draftUpload:
        return 'draft_upload';
      case MaterialProcessingStatus.uploaded:
        return 'uploaded';
      case MaterialProcessingStatus.processing:
        return 'processing';
      case MaterialProcessingStatus.ready:
        return 'ready';
      case MaterialProcessingStatus.error:
        return 'error';
    }
  }

  String get label {
    switch (this) {
      case MaterialProcessingStatus.draftUpload:
        return 'Draft upload';
      case MaterialProcessingStatus.uploaded:
        return 'Uploaded';
      case MaterialProcessingStatus.processing:
        return 'Processing';
      case MaterialProcessingStatus.ready:
        return 'Ready';
      case MaterialProcessingStatus.error:
        return 'Error';
    }
  }
}
