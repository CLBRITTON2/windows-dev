---
id: private-field-underscore
applies_to:
  - C# and C++ classes
territory:
  - "**/*.cs"
  - "**/*.cpp"
  - "**/*.cc"
  - "**/*.hpp"
---

## statement

A new private field of a class or struct takes the naming of the file's existing private fields of the same kind
(static or instance). Where the file has none, it is named `_camelCase`.

## why

The underscore tells a reader at the use site that the name is the object's state, not a local or a parameter, so an
assignment to it is a side effect on the object.

## discrimination

Flag a new private field (explicitly `private`, or C# with no access modifier) whose name breaks the pattern of the
file's existing private fields of the same kind, or, in a file with none, does not start with `_` followed by a
lowercase letter: `proxyHost`, `ProxyHost`, `m_proxyHost`, `proxyHost_`.

## example

Bad: `private string proxyHost = "";`, `private ProxySettingsViewModel proxyViewModel;`,
`private static readonly Logger logger = ...` in a new file.

Good: `private string _proxyHost = "";`, `private ProxySettingsViewModel _proxyViewModel;`,
`private static readonly Logger _logger = ...`.

## boundary

Do not flag `const` fields, public, protected or internal members, properties, locals, parameters, or fields the
change only moves. Do not ask to rename existing fields the change does not otherwise touch. Do not flag
`private static readonly Logger Logger` in a file whose sibling classes declare their logger the same way.
