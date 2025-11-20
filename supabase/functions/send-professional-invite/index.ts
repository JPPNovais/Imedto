// Edge Function: send-professional-invite
// Responsável por enviar convite por e-mail para um profissional
// e responder com CORS habilitado para uso via front-end.

const corsHeaders: HeadersInit = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
}

type InvitePayload = {
  email: string
  estabelecimentoId: string
  estabelecimentoNome: string
}

Deno.serve(async (req: Request): Promise<Response> => {
  // Preflight CORS
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  if (req.method !== 'POST') {
    return new Response('Método não permitido', {
      status: 405,
      headers: corsHeaders,
    })
  }

  try {
    const body = (await req.json()) as InvitePayload

    if (!body?.email || !body?.estabelecimentoId) {
      return new Response(
        JSON.stringify({
          error: 'email e estabelecimentoId são obrigatórios',
        }),
        {
          status: 400,
          headers: {
            ...corsHeaders,
            'Content-Type': 'application/json',
          },
        },
      )
    }

    // TODO: aqui você pode integrar com um serviço de e-mail (Resend, SES, etc.)
    // usando chaves em Deno.env.get('RESEND_API_KEY') ou similar.
    // Por enquanto, apenas registra o pedido de envio nos logs.
    console.log('Enviando convite para profissional', body)

    return new Response(
      JSON.stringify({
        success: true,
        message:
          'Convite de profissional registrado. Configure o provedor de e-mail na Edge Function para envio real.',
      }),
      {
        status: 200,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json',
        },
      },
    )
  } catch (error) {
    console.error('Erro na função send-professional-invite:', error)
    return new Response(
      JSON.stringify({ error: 'Erro interno ao enviar convite.' }),
      {
        status: 500,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json',
        },
      },
    )
  }
})

