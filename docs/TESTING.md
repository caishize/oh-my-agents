# Testing

Test strategy and structural tests. Fill in when running `/harness-init`.

## Test Commands

```bash
# Run all tests
make test     # or: npm test / cargo test / pytest

# Run specific test
make test FILE=path/to/test

# Run with coverage
make test-coverage
```

## Structural Tests

Structural tests validate architectural compliance, not business logic.
Add these to your test suite to mechanically enforce conventions.

### Layer Boundary Tests

```python
# test_architecture.py (example)
def test_layer_boundaries():
    """Each layer may only import from layers to its left.
    Types → Config → Repo → Service → Runtime → UI"""
    # Scan imports and verify direction
    pass
```

### File Size Tests

```python
def test_file_size_limits():
    """No source file should exceed 300 lines.
    Ref: docs/CONVENTIONS.md#file-size"""
    pass
```

### Naming Convention Tests

```python
def test_naming_conventions():
    """All files follow the project naming pattern.
    Ref: docs/CONVENTIONS.md#naming"""
    pass
```

## Coverage Guidelines

<!-- Define your coverage targets here -->
<!-- Example:
- New code: 80% line coverage minimum
- Critical paths (auth, payments): 95% minimum
- Structural tests: 100% (they enforce the harness)
-->

## Test Patterns

- **Tests first**: Write failing tests before implementation (see `/spec-to-task`)
- **Behavior, not implementation**: Test what code does, not how it does it
- **Structural tests enforce the harness**: Layer boundaries, naming, file sizes
- **Each taste-encoded rule needs tests**: Both positive and negative cases
