const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS"
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const openaiApiKey = Deno.env.get("OPENAI_API_KEY");
    if (!openaiApiKey) {
      throw new Error("OPENAI_API_KEY is not set.");
    }

    const { image } = await req.json();
    if (!image || typeof image !== "string") {
      throw new Error("Missing image data URL.");
    }

    const model = Deno.env.get("OPENAI_MODEL") || "gpt-4.1-mini";
    const response = await fetch("https://api.openai.com/v1/responses", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${openaiApiKey}`,
        "Content-Type": "application/json"
      },
      body: JSON.stringify({
        model,
        input: [
          {
            role: "system",
            content: [
              {
                type: "input_text",
                text: "You extract Taiwanese household receipt data. Return only JSON with date, store, category, and items. items is an array of {item, amount}. Use yyyy-mm-dd dates when visible. Amounts are numbers in TWD. If unsure, use empty strings or 0."
              }
            ]
          },
          {
            role: "user",
            content: [
              { type: "input_text", text: "Parse this receipt or invoice image for a family cashflow app." },
              { type: "input_image", image_url: image }
            ]
          }
        ],
        text: {
          format: {
            type: "json_schema",
            name: "receipt_parse",
            schema: {
              type: "object",
              additionalProperties: false,
              properties: {
                date: { type: "string" },
                store: { type: "string" },
                category: { type: "string" },
                items: {
                  type: "array",
                  items: {
                    type: "object",
                    additionalProperties: false,
                    properties: {
                      item: { type: "string" },
                      amount: { type: "number" }
                    },
                    required: ["item", "amount"]
                  }
                }
              },
              required: ["date", "store", "category", "items"]
            }
          }
        }
      })
    });

    if (!response.ok) {
      const message = await response.text();
      throw new Error(`OpenAI request failed: ${message}`);
    }

    const result = await response.json();
    const text = result.output_text || "{}";
    const parsed = JSON.parse(text);

    return new Response(JSON.stringify(parsed), {
      headers: { ...corsHeaders, "Content-Type": "application/json" }
    });
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message || String(error) }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" }
    });
  }
});
