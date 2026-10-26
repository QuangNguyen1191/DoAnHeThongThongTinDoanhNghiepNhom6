using System.Collections.Concurrent;

namespace CrmUniqlo.Api.Auth;

/// <summary>
/// Giới hạn đăng nhập (đặc tả L1 bước 1): mặc định tối đa 5 lần sai / 15 phút theo (IP, tên đăng nhập)
/// và 30 lần thử / 15 phút theo IP (cấu hình trong mục Security). Lưu trong bộ nhớ của tiến trình (đủ cho 1 máy chủ demo).
/// </summary>
public sealed class LoginThrottle
{
    public static readonly TimeSpan Window = TimeSpan.FromMinutes(15);

    private readonly ConcurrentDictionary<string, Queue<DateTimeOffset>> _failures = new();
    private readonly ConcurrentDictionary<string, Queue<DateTimeOffset>> _attempts = new();
    private readonly TimeProvider _clock;
    private readonly int _maxFailuresPerUser;
    private readonly int _maxAttemptsPerIp;

    public LoginThrottle(TimeProvider clock, Microsoft.Extensions.Options.IOptions<SecurityOptions> options)
    {
        _clock = clock;
        _maxFailuresPerUser = options.Value.LoginMaxFailuresPerUser;
        _maxAttemptsPerIp = options.Value.LoginMaxAttemptsPerIp;
    }

    private static string UserKey(string ip, string user) => $"{ip}|{user.Trim().ToLowerInvariant()}";

    /// <summary>Ghi nhận một lần thử; trả false nếu đã vượt giới hạn.</summary>
    public bool TryBegin(string ip, string user)
    {
        var now = _clock.GetUtcNow();
        if (Count(_failures, UserKey(ip, user), now, add: false) >= _maxFailuresPerUser) return false;
        return Count(_attempts, ip, now, add: true) <= _maxAttemptsPerIp;
    }

    public void Fail(string ip, string user) => Count(_failures, UserKey(ip, user), _clock.GetUtcNow(), add: true);

    public void Succeed(string ip, string user) => _failures.TryRemove(UserKey(ip, user), out _);

    private static int Count(ConcurrentDictionary<string, Queue<DateTimeOffset>> map, string key, DateTimeOffset now, bool add)
    {
        var queue = map.GetOrAdd(key, _ => new Queue<DateTimeOffset>());
        lock (queue)
        {
            while (queue.Count > 0 && now - queue.Peek() > Window) queue.Dequeue();
            if (add) queue.Enqueue(now);
            return queue.Count;
        }
    }
}
