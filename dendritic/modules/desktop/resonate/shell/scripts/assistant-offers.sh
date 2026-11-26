# Compact AH + Aldi food promotions as JSON lines, from the PrijsProfeet API
# (third-party, no key, personal use). Only promotion prices exist there; the
# assistant has to treat any other price as an estimate.
#
# Runtime inputs: bash coreutils curl jq (see default.nix).
set -euo pipefail

api="${PRIJSPROFEET_API:-https://www.prijsprofeet.nl/api/v1}"
per_category="${ASSISTANT_OFFERS_PER_CATEGORY:-12}"
# Food only; drinks, snacks, household and drugstore items are skipped.
categories=(
  groente-fruit zuivel-eieren vega kaas vlees vis brood-bakkerij ontbijt
  pasta-rijst-wereldkeuken soepen-conserven-sauzen diepvries
)
today=$(date +%F)

for retailer in albert_heijn aldi; do
  for status in active upcoming; do
    for category in "${categories[@]}"; do
      curl -fsS --max-time 30 --retry 3 --retry-delay 5 --retry-all-errors \
        -A "resonate-assistant/1.0 (personal use)" --get "$api/search" \
        --data-urlencode "q=*" \
        --data-urlencode "retailer=$retailer" \
        --data-urlencode "promotion_status=$status" \
        --data-urlencode "category=$category" \
        --data-urlencode "sort_by=savings_percentage:desc" \
        --data-urlencode "page_size=$per_category" |
        jq -c --arg today "$today" --arg store "$retailer" '
          .results[]
          | select(.valid_until >= $today)
          | {
              store: (if $store == "aldi" then "Aldi" else "AH" end),
              name, brand, price,
              was: .original_price,
              size: .quantity,
              unit_price: .unit_price,
              unit,
              type: .promotion_type,
              multi_buy: (if .multi_buy_quantity then "\(.multi_buy_quantity) for \(.multi_buy_price)" else null end),
              from: .valid_from,
              until: .valid_until,
              category: .unified_category,
              diet: (.dietary_tags // []),
              house_brand: .private_label
            }
          | with_entries(select(.value != null and .value != []))'
      # The API allows 30-120 requests/min per IP; stay well under.
      sleep 1.5
    done
  done
done
