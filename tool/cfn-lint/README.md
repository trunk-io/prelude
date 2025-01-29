To use cfn-lint, you must create a .cfnlintrc.yaml file that specifies globs matching all your templates. You should place one or more of this file as close to your templates as possible. Anytime you modify a json or yaml file in a subdirectory of this file(s) will cause the linter to run.

Example:

```
templates:
  - path/to/template.yaml
  - path/to/glob*.yaml
```

More information can be found here:
https://github.com/aws-cloudformation/cfn-lint#config-file
