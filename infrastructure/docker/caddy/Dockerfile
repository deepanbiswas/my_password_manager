# Caddy with mholt/caddy-ratelimit (not in stock image). See iterations/iteration-5-security/IMPLEMENTATION_PLAN.md
FROM caddy:builder AS builder
RUN xcaddy build \
  --with github.com/mholt/caddy-ratelimit

FROM caddy:latest
COPY --from=builder /usr/bin/caddy /usr/bin/caddy
