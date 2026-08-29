import { createClient } from 'npm:@supabase/supabase-js@2.57.4';
import { GoogleAuth } from 'npm:google-auth-library@9.15.1';

type NotificationRow = {
  id: string;
  title: string;
  body: string;
  audience: 'all_staff' | 'managers' | 'owners';
  entity_type: string | null;
  entity_id: string | null;
  push_dispatched_at: string | null;
};

type DeviceRow = {
  id: string;
  token: string;
  user_id: string;
  profiles: { role: string; active: boolean } | null;
};

const requiredEnv = (name: string): string => {
  const value = Deno.env.get(name);
  if (!value) throw new Error(`Missing ${name}`);
  return value;
};

const jsonResponse = (body: unknown, status = 200): Response =>
  new Response(JSON.stringify(body), {
    status,
    headers: { 'content-type': 'application/json' },
  });

const rolesFor = (audience: NotificationRow['audience']): string[] => {
  if (audience === 'owners') return ['owner'];
  if (audience === 'managers') return ['manager', 'owner'];
  return ['staff', 'manager', 'owner'];
};

Deno.serve(async (request) => {
  if (request.method !== 'POST') {
    return jsonResponse({ error: 'Method not allowed' }, 405);
  }

  try {
    const expectedSecret = requiredEnv('PUSH_WEBHOOK_SECRET');
    if (request.headers.get('x-webhook-secret') !== expectedSecret) {
      return jsonResponse({ error: 'Unauthorized' }, 401);
    }

    const payload = await request.json() as {
      notification_id?: string;
      record?: { id?: string };
    };
    const notificationId = payload.notification_id ?? payload.record?.id;
    if (!notificationId) {
      return jsonResponse({ error: 'notification_id is required' }, 400);
    }

    const supabase = createClient(
      requiredEnv('SUPABASE_URL'),
      requiredEnv('SUPABASE_SERVICE_ROLE_KEY'),
      { auth: { persistSession: false } },
    );

    const { data: notificationData, error: notificationError } = await supabase
      .from('notifications')
      .select('id,title,body,audience,entity_type,entity_id,push_dispatched_at')
      .eq('id', notificationId)
      .single();

    if (notificationError || !notificationData) {
      return jsonResponse({ error: 'Notification not found' }, 404);
    }

    const notification = notificationData as NotificationRow;
    if (notification.push_dispatched_at) {
      return jsonResponse({ ok: true, already_dispatched: true });
    }

    const { data: deviceData, error: deviceError } = await supabase
      .from('device_tokens')
      .select('id,token,user_id,profiles!inner(role,active)')
      .is('revoked_at', null)
      .eq('profiles.active', true)
      .in('profiles.role', rolesFor(notification.audience));

    if (deviceError) throw deviceError;
    const devices = (deviceData ?? []) as unknown as DeviceRow[];

    const serviceAccount = JSON.parse(requiredEnv('FIREBASE_SERVICE_ACCOUNT_JSON'));
    const projectId = serviceAccount.project_id as string;
    const auth = new GoogleAuth({
      credentials: serviceAccount,
      scopes: ['https://www.googleapis.com/auth/firebase.messaging'],
    });
    const authClient = await auth.getClient();
    const tokenResult = await authClient.getAccessToken();
    const accessToken = typeof tokenResult === 'string'
      ? tokenResult
      : tokenResult.token;
    if (!accessToken) throw new Error('Could not create an FCM access token');

    let delivered = 0;
    let failed = 0;
    for (const device of devices) {
      const response = await fetch(
        `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
        {
          method: 'POST',
          headers: {
            authorization: `Bearer ${accessToken}`,
            'content-type': 'application/json',
          },
          body: JSON.stringify({
            message: {
              token: device.token,
              notification: {
                title: notification.title,
                body: notification.body,
              },
              data: {
                notification_id: notification.id,
                entity_type: notification.entity_type ?? '',
                entity_id: notification.entity_id ?? '',
              },
              webpush: {
                fcm_options: {
                  link: Deno.env.get('ADMIN_URL') ?? 'https://evils.space/admin',
                },
              },
            },
          }),
        },
      );

      const providerBody = await response.json().catch(() => ({}));
      const state = response.ok ? 'delivered' : 'failed';
      delivered += response.ok ? 1 : 0;
      failed += response.ok ? 0 : 1;

      await supabase.from('notification_deliveries').upsert({
        notification_id: notification.id,
        user_id: device.user_id,
        device_token_id: device.id,
        state,
        provider_message_id: response.ok ? providerBody.name ?? null : null,
        error: response.ok ? null : JSON.stringify(providerBody).slice(0, 2000),
        delivered_at: response.ok ? new Date().toISOString() : null,
      }, { onConflict: 'notification_id,user_id,device_token_id' });
    }

    if (failed === 0) {
      await supabase
        .from('notifications')
        .update({ push_dispatched_at: new Date().toISOString() })
        .eq('id', notification.id);
    }

    return jsonResponse({ ok: failed === 0, devices: devices.length, delivered, failed });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    return jsonResponse({ error: message }, 500);
  }
});
