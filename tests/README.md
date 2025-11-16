# Premier League MATLAB App Tests

This directory contains test suites for the Premier League app.

## Running Tests

### Run All Tests
```matlab
cd('c:\Users\ydebray\Downloads\premier-league')
results = runtests('tests')
```

### Run Specific Test Suite
```matlab
results = runtests('tests/testBadgeFetching.m')
```

### Quick Test in MATLAB MCP Session
The tests automatically add the `src` path, so you can run directly:
```matlab
runtests('tests/testBadgeFetching.m')
```

### Run Tests with Tags
```matlab
% Run only integration tests
results = runtests('tests', 'Tag', 'Integration')

% Run only performance tests
results = runtests('tests', 'Tag', 'Performance')
```

### Generate Test Report
```matlab
import matlab.unittest.TestRunner
import matlab.unittest.plugins.TestReportPlugin

runner = TestRunner.withTextOutput;
plugin = TestReportPlugin.producingHTML('test-results');
runner.addPlugin(plugin);
results = runner.run(testsuite('tests'));
```

## Test Coverage

### Badge Fetching Tests (`testBadgeFetching.m`)

Tests the SportsDB API integration for team badges:

- **Canonical Name Mapping**: Verifies team name transformations (e.g., "Man City" → "Manchester City")
- **API Integration**: Tests actual badge URL fetching from TheSportsDB
- **Cache Behavior**: Validates caching mechanism and performance
- **Error Handling**: Tests invalid team names and empty URLs
- **Image Setting**: Verifies badge display in UI

#### Test Categories

1. **Unit Tests** (default)
   - Individual function behavior
   - Name mapping logic
   - Cache operations

2. **Integration Tests** (`Tag: 'Integration'`)
   - Full workflow from team selection to badge display
   - End-to-end API calls

3. **Performance Tests** (`Tag: 'Performance'`)
   - API response time validation
   - Cache performance benchmarks

## Test Results Interpretation

- **Green (Passed)**: All assertions passed
- **Yellow (Warning)**: Test passed but took longer than expected
- **Red (Failed)**: Assertion failed or error occurred

## Notes

- Some tests require internet connectivity to access TheSportsDB API
- Network timeouts are handled gracefully in test cases
- Performance tests validate that caching provides significant speedup
- The test suite automatically creates and destroys app instances
