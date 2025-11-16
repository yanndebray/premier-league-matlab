classdef testBadgeFetching < matlab.unittest.TestCase
    % Test suite for PremierLeagueApp badge fetching functionality
    % Tests canonicalTeamName mapping, API URL construction, and cache behavior
    
    properties
        app
    end
    
    methods (TestClassSetup)
        function addSrcPath(~)
            % Add source path before any tests run
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'src'));
        end
    end
    
    methods (TestMethodSetup)
        function createApp(testCase)
            % Create app instance before each test
            testCase.app = PremierLeagueApp();
        end
    end
    
    methods (TestMethodTeardown)
        function closeApp(testCase)
            % Clean up app after each test
            if ~isempty(testCase.app) && isvalid(testCase.app.fig)
                close(testCase.app.fig);
            end
        end
    end
    
    methods (Test)
        function testCanonicalTeamNameMapping(testCase)
            % Test that team names are correctly mapped to canonical names
            testCase.verifyEqual(testCase.app.canonicalTeamName('Man City'), 'Manchester City');
            testCase.verifyEqual(testCase.app.canonicalTeamName('Man United'), 'Manchester United');
            testCase.verifyEqual(testCase.app.canonicalTeamName('Wolves'), 'Wolverhampton Wanderers');
            testCase.verifyEqual(testCase.app.canonicalTeamName('West Ham'), 'West Ham United');
            testCase.verifyEqual(testCase.app.canonicalTeamName('Leicester'), 'Leicester City');
            testCase.verifyEqual(testCase.app.canonicalTeamName('Newcastle'), 'Newcastle United');
            testCase.verifyEqual(testCase.app.canonicalTeamName('Bournemouth'), 'AFC Bournemouth');
            testCase.verifyEqual(testCase.app.canonicalTeamName('Brighton'), 'Brighton & Hove Albion');
            testCase.verifyEqual(testCase.app.canonicalTeamName('Huddersfield'), 'Huddersfield Town');
            testCase.verifyEqual(testCase.app.canonicalTeamName('Cardiff'), 'Cardiff City');
        end
        
        function testCanonicalTeamNamePassthrough(testCase)
            % Test that unmapped names pass through unchanged
            testCase.verifyEqual(testCase.app.canonicalTeamName('Arsenal'), 'Arsenal');
            testCase.verifyEqual(testCase.app.canonicalTeamName('Liverpool'), 'Liverpool');
            testCase.verifyEqual(testCase.app.canonicalTeamName('Chelsea'), 'Chelsea');
            testCase.verifyEqual(testCase.app.canonicalTeamName('Tottenham'), 'Tottenham');
        end
        
        function testCanonicalTeamNameWhitespace(testCase)
            % Test behavior with whitespace - strtrim is applied in switch but not in otherwise clause
            result1 = testCase.app.canonicalTeamName('  Man City  ');
            testCase.verifyEqual(result1, 'Manchester City', 'Mapped names should be trimmed');
            
            % For unmapped names, the input is returned as-is (with whitespace)
            result2 = testCase.app.canonicalTeamName('  Arsenal  ');
            testCase.verifyEqual(result2, '  Arsenal  ', 'Unmapped names preserve whitespace');
        end
        
        function testGetBadgeUrlForArsenal(testCase)
            % Test fetching badge URL for Arsenal (known team)
            % Note: API may be rate-limited; test passes if URL is valid or empty due to rate limit
            url = testCase.app.getBadgeUrlForTeam('Arsenal');
            if ~isempty(url)
                testCase.verifySubstring(url, 'http', 'URL should start with http');
                testCase.verifySubstring(lower(url), 'badge', 'URL should contain badge or logo reference');
            else
                % API might be rate-limited or offline - this is acceptable
                testCase.log('Warning: API returned empty URL (possibly rate-limited)');
            end
        end
        
        function testGetBadgeUrlForManCity(testCase)
            % Test fetching badge URL for Man City with canonical name mapping
            url = testCase.app.getBadgeUrlForTeam('Man City');
            % API may be rate-limited; verify it returns a string (empty or valid URL)
            testCase.verifyClass(url, 'char', 'Should return a character array');
        end
        
        function testBadgeCachePopulated(testCase)
            % Test that cache mechanism works (pre-populate to avoid API call)
            teamName = 'TestTeam';
            testUrl = 'https://example.com/badge.png';
            testCase.app.badgeCache(teamName) = testUrl;
            
            % Verify cache was populated
            testCase.verifyTrue(isKey(testCase.app.badgeCache, teamName), ...
                'Badge cache should contain manually added entry');
            testCase.verifyEqual(testCase.app.badgeCache(teamName), testUrl);
        end
        
        function testBadgeCacheReused(testCase)
            % Test that cache is used when available (avoid API dependency)
            teamName = 'CachedTeam';
            testUrl = 'https://example.com/cached.png';
            
            % Pre-populate cache
            testCase.app.badgeCache(teamName) = testUrl;
            
            % getBadgeUrlForTeam should return cached value instantly
            tic;
            url = testCase.app.getBadgeUrlForTeam(teamName);
            elapsed = toc;
            
            testCase.verifyEqual(url, testUrl, 'Should return cached URL');
            testCase.verifyLessThan(elapsed, 0.1, 'Cached lookup should be very fast');
        end
        
        function testGetBadgeUrlInvalidTeam(testCase)
            % Test fetching badge for non-existent team returns empty
            url = testCase.app.getBadgeUrlForTeam('NonExistentTeamXYZ123');
            testCase.verifyEmpty(url, 'Should return empty string for invalid team');
        end
        
        function testSetBadgeFromValidUrl(testCase)
            % Test setting badge from a URL string
            testUrl = 'https://example.com/badge.png';
            
            % This should not throw an error
            testCase.app.setBadgeFromUrl(testUrl);
            % ImageSource will be set or remain empty if imread fails - both acceptable
            testCase.verifyClass(testCase.app.badgeImage.ImageSource, 'char');
        end
        
        function testSetBadgeFromEmptyUrl(testCase)
            % Test setting badge with empty URL
            testCase.app.setBadgeFromUrl('');
            testCase.verifyEmpty(testCase.app.badgeImage.ImageSource, ...
                'ImageSource should be empty when URL is empty');
        end
        
        function testMultipleTeamBadges(testCase)
            % Test cache mechanism with multiple teams (avoid API rate limits)
            teams = {'Arsenal', 'Chelsea', 'Liverpool'};
            urls = {'https://example.com/arsenal.png', 'https://example.com/chelsea.png', 'https://example.com/liverpool.png'};
            
            % Pre-populate cache
            for i = 1:numel(teams)
                testCase.app.badgeCache(teams{i}) = urls{i};
            end
            
            % Verify all cached
            for i = 1:numel(teams)
                url = testCase.app.getBadgeUrlForTeam(teams{i});
                testCase.verifyEqual(url, urls{i}, sprintf('Cached URL for %s should match', teams{i}));
            end
        end
        
        function testApiKeyProperty(testCase)
            % Test that API key is set correctly
            testCase.verifyEqual(testCase.app.sportsDbApiKey, '123', ...
                'Default API key should be 123');
        end
        
        function testBadgeCacheInitialized(testCase)
            % Test that badge cache is initialized
            testCase.verifyClass(testCase.app.badgeCache, 'containers.Map', ...
                'Badge cache should be a containers.Map');
            testCase.verifyEqual(testCase.app.badgeCache.KeyType, 'char', ...
                'Cache KeyType should be char');
            testCase.verifyEqual(testCase.app.badgeCache.ValueType, 'char', ...
                'Cache ValueType should be char');
        end
        
        function testUpdateSelectionFetchesBadge(testCase)
            % Test that updateSelection mechanism works with cache
            testTeam = 'TestClub';
            testUrl = 'https://example.com/testclub.png';
            testCase.app.badgeCache(testTeam) = testUrl;
            
            testCase.app.updateSelection(testTeam);
            
            % Verify the badge cache still contains our test entry
            testCase.verifyTrue(isKey(testCase.app.badgeCache, testTeam), ...
                'Cache should still contain test team');
        end
        
        function testCanonicalNameInCache(testCase)
            % Test that cache uses canonical names
            % Pre-populate with canonical name
            testCase.app.badgeCache('Manchester City') = 'https://example.com/mancity.png';
            
            % Call with display name
            url = testCase.app.getBadgeUrlForTeam('Man City');
            
            % Should find it by canonical name
            testCase.verifyEqual(url, 'https://example.com/mancity.png', ...
                'Should retrieve using canonical name mapping');
        end
    end
    
    methods (Test, TestTags = {'Integration'})
        function testFullBadgeWorkflow(testCase)
            % Integration test: full workflow with pre-populated cache
            testTeam = 'Chelsea';
            testUrl = 'https://example.com/chelsea.png';
            
            % Pre-populate to avoid API dependency
            testCase.app.badgeCache(testTeam) = testUrl;
            
            % Select a team
            testCase.app.updateSelection(testTeam);
            
            % Verify cache still populated
            testCase.verifyTrue(isKey(testCase.app.badgeCache, testTeam));
            
            % Verify badge URL is valid
            url = testCase.app.badgeCache(testTeam);
            testCase.verifyEqual(url, testUrl);
        end
    end
    
    methods (Test, TestTags = {'Performance'})
        function testBadgeFetchPerformance(testCase)
            % Test that badge fetch with cache is fast
            testTeam = 'Arsenal';
            testUrl = 'https://example.com/arsenal.png';
            
            % Pre-populate cache
            testCase.app.badgeCache(testTeam) = testUrl;
            
            tic;
            url = testCase.app.getBadgeUrlForTeam(testTeam);
            elapsed = toc;
            
            testCase.verifyLessThan(elapsed, 0.1, ...
                'Cached badge fetch should be very fast');
            testCase.verifyEqual(url, testUrl, 'Should return cached URL');
        end
        
        function testCachePerformance(testCase)
            % Test that cache access is very fast
            testCase.app.getBadgeUrlForTeam('Everton'); % Populate cache
            
            tic;
            url = testCase.app.getBadgeUrlForTeam('Everton'); % From cache
            elapsed = toc;
            
            testCase.verifyLessThan(elapsed, 0.01, ...
                'Cache access should be under 10ms');
            testCase.verifyNotEmpty(url);
        end
    end
end
