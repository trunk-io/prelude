[
  {
    "line": "import sys\n",
    "results": [
      {
        "column": 1,
        "rule_id": "F401",
        "message": "'sys' imported but unused"
      },
      {
        "column": 1,
        "rule_id": "E402",
        "message": "module level import not at top of file"
      }
    ]
  },
  {
    "line": "# trunk-ignore(flake8/F401): this will trigger a warning to verify that the config is applied\n",
    "results": [
      {
        "column": 80,
        "rule_id": "E501",
        "message": "line too long (93 > 79 characters)"
      }
    ]
  }
]