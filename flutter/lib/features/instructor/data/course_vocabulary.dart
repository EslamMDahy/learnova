enum CourseLifecycleStatus { draft, published, archived, active }

enum CourseAccessType { individual, organization }

enum CourseVisibility { private, public, unlisted }

CourseLifecycleStatus parseCourseLifecycleStatus(String? raw) {
  switch ((raw ?? '').trim().toLowerCase()) {
    case 'published':
      return CourseLifecycleStatus.published;
    case 'archived':
      return CourseLifecycleStatus.archived;
    case 'active':
      return CourseLifecycleStatus.active;
    case 'draft':
    default:
      return CourseLifecycleStatus.draft;
  }
}

CourseAccessType parseCourseAccessType(String? raw) {
  switch ((raw ?? '').trim().toLowerCase()) {
    case 'organization':
      return CourseAccessType.organization;
    case 'individual':
    default:
      return CourseAccessType.individual;
  }
}

CourseVisibility parseCourseVisibility(String? raw) {
  switch ((raw ?? '').trim().toLowerCase()) {
    case 'public':
      return CourseVisibility.public;
    case 'unlisted':
      return CourseVisibility.unlisted;
    case 'private':
    default:
      return CourseVisibility.private;
  }
}

extension CourseLifecycleStatusBackend on CourseLifecycleStatus {
  String get backendValue {
    switch (this) {
      case CourseLifecycleStatus.draft:
        return 'draft';
      case CourseLifecycleStatus.published:
        return 'published';
      case CourseLifecycleStatus.archived:
        return 'archived';
      case CourseLifecycleStatus.active:
        return 'active';
    }
  }

  String get label {
    switch (this) {
      case CourseLifecycleStatus.draft:
        return 'Draft';
      case CourseLifecycleStatus.published:
      case CourseLifecycleStatus.active:
        return 'Active';
      case CourseLifecycleStatus.archived:
        return 'Archived';
    }
  }
}

extension CourseAccessTypeBackend on CourseAccessType {
  String get backendValue {
    switch (this) {
      case CourseAccessType.individual:
        return 'individual';
      case CourseAccessType.organization:
        return 'organization';
    }
  }

  String get label {
    switch (this) {
      case CourseAccessType.individual:
        return 'Individual';
      case CourseAccessType.organization:
        return 'Organization';
    }
  }
}

extension CourseVisibilityBackend on CourseVisibility {
  String get backendValue {
    switch (this) {
      case CourseVisibility.private:
        return 'private';
      case CourseVisibility.public:
        return 'public';
      case CourseVisibility.unlisted:
        return 'unlisted';
    }
  }

  String get label {
    switch (this) {
      case CourseVisibility.private:
        return 'Private';
      case CourseVisibility.public:
        return 'Public';
      case CourseVisibility.unlisted:
        return 'Unlisted';
    }
  }
}
