#!/usr/bin/env python3
"""
Helper script to generate airdrop CSV with proper wei amounts
Usage: python generate_airdrop_csv.py
"""

import csv

def tokens_to_wei(amount, decimals=18):
    """Convert token amount to wei (assuming 18 decimals for AIV)"""
    return int(amount * (10 ** decimals))

# Define your airdrop distribution here
airdrop_data = [
    # (address, amount_in_tokens)
    ("0x742e8D0aED6e21E2F8daBF7c8D9b3D96aF61f5a4", 1000),
    ("0x1234567890123456789012345678901234567890", 500),
    ("0xabcdefabcdefabcdefabcdefabcdefabcdefabcd", 750),
    ("0x9876543210987654321098765432109876543210", 250),
    ("0xfedcba0987654321fedcba0987654321fedcba09", 300),
    # Add more recipients here
]

def generate_csv():
    with open('airdrop_distribution.csv', 'w', newline='') as csvfile:
        writer = csv.writer(csvfile)
        
        # Write header
        writer.writerow(['address', 'amount'])
        
        # Write data
        for address, token_amount in airdrop_data:
            wei_amount = tokens_to_wei(token_amount)
            writer.writerow([address, wei_amount])
    
    print(f"Generated airdrop_distribution.csv with {len(airdrop_data)} recipients")
    
    # Calculate total
    total_tokens = sum(amount for _, amount in airdrop_data)
    total_wei = tokens_to_wei(total_tokens)
    print(f"Total tokens to distribute: {total_tokens:,} AIV")
    print(f"Total wei amount: {total_wei}")

if __name__ == "__main__":
    generate_csv() 