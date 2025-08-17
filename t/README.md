# Ásbrú Connection Manager Test Suite

This directory contains the comprehensive test suite for Ásbrú Connection Manager 7.0.0, including automated GUI tests, connection protocol tests, and performance benchmarks.

## Test Structure

- `gui/` - GUI functionality and widget tests
- `protocols/` - Connection protocol validation tests  
- `performance/` - Performance benchmarking and integration tests
- `lib/` - Shared test utilities and frameworks
- `fixtures/` - Test data and configuration files

## Running Tests

### All Tests
```bash
perl t/run_all_tests.pl
```

### GUI Tests Only
```bash
perl t/gui/run_gui_tests.pl
```

### Protocol Tests Only
```bash
perl t/protocols/run_protocol_tests.pl
```

### Performance Tests Only
```bash
perl t/performance/run_performance_tests.pl
```

## Requirements

- Perl 5.20+
- GTK4 development libraries
- Test::More, Test::MockObject, Benchmark modules
- Xvfb for headless GUI testing
- Docker (optional, for isolated protocol testing)

## AI Assistance Disclosure

This test suite was developed with AI assistance as part of the Ásbrú Connection Manager modernization project. All test implementations follow established Perl testing best practices while ensuring compatibility with the GTK4 migration.