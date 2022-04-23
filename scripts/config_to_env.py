#!/usr/bin/env python
import json
import argparse

def parse_args():
  parser = argparse.ArgumentParser()
  parser.add_argument("config_json")
  parser.add_argument("output_file")

  return parser.parse_args()

def dict_to_env_file(parent_key, indict, f_out):
  for key, value in indict.items():
    if isinstance(value, (str, float, int)):
      print(f"{(parent_key + '.') if parent_key else ''}{str(key)}={str(value)}", file = f_out)
    elif isinstance(value, dict):
      dict_to_env_file((parent_key + '.' + key) if parent_key else key, value, f_out)
    elif isinstance(value, list):
      pass

def main():
  args = parse_args()
  print(args)

  with open(args.config_json, 'r') as f_in, open(args.output_file, 'w') as f_out:
    dict_to_env_file(None, json.load(f_in), f_out)

if __name__ == '__main__':
  main()
