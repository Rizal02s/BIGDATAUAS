class EmployeeDeletionFailure implements Exception {
  final String message;
  final bool pending;
  const EmployeeDeletionFailure(this.message, {this.pending = false});
}
