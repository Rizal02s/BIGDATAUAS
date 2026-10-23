// No client-supplied role or privileged key is trusted. Auth and SQL both authorize the caller.
export function createHandler({ url, anonKey, serviceKey, fetchImpl = fetch }) {
  const headers = {
    'content-type': 'application/json',
    'access-control-allow-origin': '*',
    'access-control-allow-headers': 'authorization, x-client-info, apikey, content-type',
    'access-control-allow-methods': 'POST, OPTIONS',
  };
  const reply = (status, body) => new Response(JSON.stringify(body), { status, headers });
  const call = async (path, token, key, body, method = 'POST') => {
    const response = await fetchImpl(`${url}${path}`, {
      method, headers: { authorization: `Bearer ${token}`, apikey: key, 'content-type': 'application/json' },
      ...(body === undefined ? {} : { body: JSON.stringify(body) }),
    });
    let data;
    try { data = await response.json(); } catch { data = {}; }
    return { ok: response.ok, status: response.status, data };
  };
  return async (request) => {
    if (request.method === 'OPTIONS') return new Response('ok', { headers });
    if (request.method !== 'POST') return reply(405, { error: 'Gunakan POST.' });
    if (!url || !anonKey || !serviceKey) return reply(503, { error: 'Fungsi hapus akun belum dikonfigurasi di server.' });
    const token = request.headers.get('authorization')?.match(/^Bearer\s+(\S+)$/i)?.[1];
    if (!token) return reply(401, { error: 'Masuk kembali sebelum menghapus akun.' });
    let body;
    try {
      const text = await request.text();
      if (text.length > 4096) return reply(400, { error: 'Permintaan terlalu panjang.' });
      body = JSON.parse(text);
    } catch { return reply(400, { error: 'Permintaan penghapusan tidak valid.' }); }
    if (!body || typeof body !== 'object' || Array.isArray(body) ||
        typeof body.id !== 'string' || !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(body.id) ||
        !['staff', 'technician', 'admin', 'pending', 'disabled'].includes(body.expected_role) ||
        typeof body.reason !== 'string' || body.reason.trim().length < 5 || body.reason.trim().length > 500) {
      return reply(400, { error: 'ID, peran, atau alasan penghapusan tidak valid.' });
    }
    let prepared = false;
    try {
      const user = await call('/auth/v1/user', token, anonKey, undefined, 'GET');
      if (!user.ok || !user.data.id) return reply(401, { error: 'Sesi tidak valid. Masuk kembali.' });
      if (user.data.id === body.id) return reply(400, { error: 'Akun sendiri tidak dapat dihapus.' });
      const start = await call('/rest/v1/rpc/prepare_employee_deletion', token, anonKey,
        { p_id: body.id, p_expected_role: body.expected_role, p_reason: body.reason.trim() });
      if (!start.ok) {
        if (start.data.code === 'PGRST202') return reply(503, { error: 'Jalankan migrasi 013_delete_employee_account.sql terlebih dahulu.' });
        return reply(403, { error: start.data.message || 'Hanya owner yang dapat menghapus akun pegawai.' });
      }
      prepared = true;
      if (start.data.auth_deleted === true) return reply(200, { deleted: true, id: body.id });
      const deleted = await call(`/auth/v1/admin/users/${body.id}`, serviceKey, serviceKey, { should_soft_delete: true }, 'DELETE');
      if (!deleted.ok) {
        // Recover a lost response / already-deleted Auth identity before acknowledging success.
        const current = await call(`/auth/v1/admin/users/${body.id}`, serviceKey, serviceKey, undefined, 'GET');
        if (!(current.status === 404 || (current.ok && (current.data.deleted_at || current.data.user?.deleted_at)))) {
          return reply(503, { pending: true, id: body.id, error: 'Akses aplikasi sudah dicabut. Penghapusan login belum selesai; coba lagi pada akun yang sama.' });
        }
      }
      const finished = await call('/rest/v1/rpc/finish_employee_deletion', serviceKey, serviceKey, { p_id: body.id });
      if (!finished.ok) return reply(503, { pending: true, id: body.id, error: 'Penghapusan login perlu diperiksa ulang. Coba lagi pada akun yang sama.' });
      return reply(200, { deleted: true, id: body.id });
    } catch {
      return reply(503, { pending: prepared, id: body.id, error: prepared
        ? 'Akses aplikasi sudah dicabut. Penyelesaian penghapusan perlu dicoba lagi pada akun yang sama.'
        : 'Server belum dapat dihubungi. Coba lagi tanpa mengganti akun yang dipilih.' });
    }
  };
}
