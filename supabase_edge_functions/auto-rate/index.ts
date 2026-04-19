// Supabase Edge Function: Auto-Rate
// Deploy: supabase functions deploy auto-rate
// Schedule as cron: runs every hour
// Purpose: Auto 5-star rating after 24 hours if customer hasn't rated

// @ts-ignore: Deno ESM import — works at runtime on Supabase Edge Functions
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

declare const Deno: {
  env: { get(key: string): string | undefined }
  serve(handler: (req: Request) => Response | Promise<Response>): void
}

const supabaseUrl = Deno.env.get('SUPABASE_URL')!
const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const supabase = createClient(supabaseUrl, supabaseServiceKey)

Deno.serve(async () => {
  try {
    const cutoff = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString()

    // Auto-rate food orders delivered > 24h ago without a rating
    const { data: unratedOrders } = await supabase
      .from('orders')
      .select('id, customer_id, rider_id, merchant_id')
      .eq('status', 'delivered')
      .lt('delivered_at', cutoff)

    for (const order of (unratedOrders || [])) {
      const { data: existing } = await supabase
        .from('ratings')
        .select('id')
        .eq('order_id', order.id)
        .maybeSingle()

      if (!existing) {
        await supabase.from('ratings').insert({
          order_id: order.id,
          customer_id: order.customer_id,
          rider_rating: 5,
          merchant_rating: 5,
          is_auto_rated: true,
          comment: 'Auto-rated (no customer feedback within 24hrs)',
        })
      }
    }

    // Auto-rate completed pahapit > 24h ago without a rating
    const { data: unratedPahapit } = await supabase
      .from('pahapit_requests')
      .select('id, customer_id, rider_id')
      .eq('status', 'completed')
      .lt('completed_at', cutoff)

    for (const job of (unratedPahapit || [])) {
      const { data: existing } = await supabase
        .from('ratings')
        .select('id')
        .eq('pahapit_id', job.id)
        .maybeSingle()

      if (!existing) {
        await supabase.from('ratings').insert({
          pahapit_id: job.id,
          customer_id: job.customer_id,
          rider_rating: 5,
          is_auto_rated: true,
          comment: 'Auto-rated (no customer feedback within 24hrs)',
        })
      }
    }

    return new Response(JSON.stringify({ success: true }), {
      headers: { 'Content-Type': 'application/json' },
    })
  } catch (error) {
    return new Response(JSON.stringify({ error: (error as Error).message }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    })
  }
})
