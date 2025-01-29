[
  {
    "line": "foo(\"wrong\")\n",
    "results": [
      {
        "column": 5,
        "rule_id": "reportArgumentType",
        "message": "Argument of type \"Literal['wrong']\" cannot be assigned to parameter \"bar\" of type \"int\" in function \"foo\"\n  \"Literal['wrong']\" is not assignable to \"int\""
      }
    ]
  }
]