import Foundation

/// A view's appearance task can be cancelled and restarted during a presentation change.
/// Its live prayer keeps one initialization running, and the next appearance awaits it.
@MainActor
final class PrayerSessionLoader {
  private var task: Task<Void, Never>?

  func perform(_ operation: @escaping @MainActor () async -> Void) async {
    if let task {
      await task.value
      return
    }
    let task = Task { await operation() }
    self.task = task
    await task.value
    self.task = nil
  }
}
