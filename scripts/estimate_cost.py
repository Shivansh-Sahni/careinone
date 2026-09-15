#!/usr/bin/env python3
"""Planning estimate only; tokens include prompt/chunks/retries and reasoning where billed."""
import argparse
from decimal import Decimal

RATES = {
    'gpt-4.1-mini': (Decimal('0.40'), Decimal('1.60')),
    'gpt-4.1-nano': (Decimal('0.10'), Decimal('0.40')),
}

def estimate(users, uploads, cloud_fraction, cache_fraction, input_tokens, output_tokens, input_rate, output_rate, retry_fraction):
    calls = users * uploads * cloud_fraction * (1 - cache_fraction)
    cost = calls * (input_tokens * input_rate + output_tokens * output_rate) / Decimal(1_000_000)
    return calls, cost * (1 + retry_fraction)

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--users', type=int, default=1000)
    parser.add_argument('--uploads', type=int, default=10, help='Monthly sources per active user')
    parser.add_argument('--cloud-fraction', type=Decimal, default=Decimal('1'))
    parser.add_argument('--cache-fraction', type=Decimal, default=Decimal('0'), help='Uploads avoided by local exact reuse; not provider prompt-cache pricing')
    parser.add_argument('--input-tokens', type=int, default=3000, help='Total billed input tokens per source, including all chunks and prompts')
    parser.add_argument('--output-tokens', type=int, default=1000, help='Total billed output tokens including reasoning, if any')
    parser.add_argument('--retry-fraction', type=Decimal, default=Decimal('0.10'))
    parser.add_argument('--hosting', type=Decimal, default=Decimal('7'), help='Monthly hosting allowance, not a quote')
    parser.add_argument('--custom-input-rate', type=Decimal)
    parser.add_argument('--custom-output-rate', type=Decimal)
    args = parser.parse_args()
    numbers = [args.cloud_fraction,args.cache_fraction,args.retry_fraction,args.hosting]
    numbers += [x for x in (args.custom_input_rate,args.custom_output_rate) if x is not None]
    if any(not x.is_finite() or x < 0 for x in numbers) or not 0 <= args.cloud_fraction <= 1 or not 0 <= args.cache_fraction <= 1 or min(args.users,args.uploads,args.input_tokens,args.output_tokens) < 0:
        parser.error('Use finite nonnegative quantities and fractions in 0..1')
    if (args.custom_input_rate is None) != (args.custom_output_rate is None): parser.error('Supply both custom rates')
    rates = dict(RATES)
    if args.custom_input_rate is not None: rates['custom-provider']=(args.custom_input_rate,args.custom_output_rate)
    print('USD planning scenario; standard uncached rates checked 2026-09-15. Not an invoice or quality comparison.')
    for model, (input_rate,output_rate) in rates.items():
        calls, cost=estimate(args.users,args.uploads,args.cloud_fraction,args.cache_fraction,args.input_tokens,args.output_tokens,input_rate,output_rate,args.retry_fraction)
        print(f'{model:20} sources={calls:,.0f} API=${cost:,.2f} hosting allowance=${args.hosting:,.2f} total=${cost+args.hosting:,.2f}/month')
    print('Excludes Apple membership, taxes, enrollment/operations, network egress, registry/build/secrets fees, and any backup storage. Reasoning tokens and retries can change totals.')

if __name__ == '__main__': main()
