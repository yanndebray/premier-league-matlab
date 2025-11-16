classdef PremierLeagueApp < handle
    % PremierLeagueApp - MATLAB replica of the shown Premier League visualization
    % Usage:
    %   app = PremierLeagueApp;  % launches UI
    %
    % Notes:
    % - Data is embedded for 2018-2019 sample season. Extend by editing loadData().
    % - Row coloring uses uistyle (requires relatively recent MATLAB). Falls back to HTML if unavailable.
    % - W/D/L trend shown as colored patches for last 10 matches.
    % - This is a programmatic UI; no .mlapp dependency.

    properties
        % Top-level figure & layout sections
        fig
        headerPanel
        standingsPanel
        detailsPanel
        plotPanel
        legendPanel
        % UI components
        standingsTable
        seasonDropDown
        segmentGroup
        badgeImage matlab.ui.control.Image
        htmlDetails matlab.ui.control.HTML
        positionAxes
        % Data & state
        data struct
        seasonData struct
        selectedSeason char = '2018-2019'
        selectedTeam char = 'Man City'
        styleMode char = 'uistyle' % 'uistyle' or 'html'
        % Constant configuration (colors, thresholds)
        C struct
        % External API config and cache
        sportsDbApiKey char = '123'
        badgeCache
    end

    methods
        function app = PremierLeagueApp()
            app.detectStyleMode();     % Decide styling approach
            app.defineConstants();     % Colors & thresholds
            app.loadData();            % Load season data
            app.buildUI();             % Compose UI sections
            app.badgeCache = containers.Map('KeyType','char','ValueType','char');
            app.updateSeason(app.selectedSeason); % Populate initial season
            app.updateSelection(app.selectedTeam);% Populate team details
        end

        function detectStyleMode(app)
            try
                uistyle; %#ok<VUNUS>
                app.styleMode = 'uistyle';
            catch
                app.styleMode = 'html';
            end
        end

        function loadData(app)
            % Load embedded seasons. Extend by adding more blocks.
            if isempty(app.data); app.data = struct(); end
            seasons = { '2018-2019','Sample-Next'}; % second season placeholder
            for sIdx = 1:numel(seasons)
                season = seasons{sIdx}; key = matlab.lang.makeValidName(season);
                if strcmp(season,'2018-2019')
                    teams = { 'Man City','Liverpool','Chelsea','Tottenham','Arsenal','Man United','Wolves','Everton','Leicester','Watford','West Ham','Crystal Palace','Newcastle','Bournemouth','Burnley','Southampton','Brighton','Cardiff','Fulham','Huddersfield'};
                    raw = [32 30 21 23 21 19 16 15 15 14 15 14 12 13 11 9 9 10 7 3; ... % W
                           2 7 8 2 7 9 9 9 7 8 7 5 9 7 7 12 9 4 5 7; ...               % D
                           4 1 9 13 10 10 12 14 16 16 16 19 17 18 20 17 20 24 26 28];   % L
                    GFvals = [95 89 63 67 73 65 47 54 51 52 52 51 42 56 45 45 35 34 34 22];
                    GAvals = [23 22 39 39 51 54 46 46 48 59 55 53 48 65 68 65 60 69 81 76];
                else
                    % Placeholder season with slightly varied stats
                    teams = { 'Man City','Liverpool','Chelsea','Tottenham','Arsenal','Man United','Newcastle','Brighton','Leicester','Everton','West Ham','Wolves','Burnley','Bournemouth','Southampton','Crystal Palace','Watford','Brentford','Fulham','Luton'};
                    rng(42); raw = randi([10 30],3,numel(teams));
                end
                MP = 38*ones(1,numel(teams));
                if strcmp(season,'2018-2019')
                    standings = struct('Club',teams,'MP',num2cell(MP),'W',num2cell(raw(1,:)),'D',num2cell(raw(2,:)),'L',num2cell(raw(3,:)), ...
                                        'GF',num2cell(GFvals),'GA',num2cell(GAvals));
                else
                    standings = struct('Club',teams,'MP',num2cell(MP),'W',num2cell(raw(1,:)),'D',num2cell(raw(2,:)),'L',num2cell(raw(3,:)), ...
                                        'GF',num2cell(randi([30 95],1,numel(teams))),'GA',num2cell(randi([20 85],1,numel(teams))));
                end
                for i=1:numel(standings)
                    standings(i).GD = standings(i).GF - standings(i).GA;
                    standings(i).Points = standings(i).W*3 + standings(i).D;
                end
                matchdays = 38; rng(sIdx*7);
                posMatrix = zeros(numel(teams),matchdays);
                for t=1:numel(teams)
                    if t==1
                        % Man City - strong finish at 1st
                        posMatrix(t,:) = [14 3 2 2 1 1 1 1 1 1 1 1 1 1 1 1 1 2 2 2 2 2 2 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1];
                    elseif t==2
                        % Liverpool - strong but 2nd
                        posMatrix(t,:) = [8 6 4 3 2 2 2 2 2 2 2 2 2 2 2 2 2 1 1 1 1 1 1 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2];
                    else
                        % Other teams with realistic variation
                        walk = cumsum(0.3*randn(1,matchdays));
                        target = min(t,20); % final position roughly by standing
                        posMatrix(t,:) = max(1,min(20,round(target + walk)));
                    end
                end
                % Cards & results
                cards = struct(); results = struct();
                for t=1:numel(teams)
                    nm = matlab.lang.makeValidName(teams{t});
                    cards.(nm) = struct('Red', randi([0 3]), 'Yellow', randi([20 70]));
                    results.(nm) = randi([0 2],1,10); % 0=L,1=D,2=W
                end
                app.data.(key) = struct('Standings',standings,'Positions',posMatrix,'Matchdays',matchdays,'Cards',cards,'Results',results);
            end
        end

        function defineConstants(app)
            % Define color palette & thresholds used across app
            app.C = struct();
            app.C.colors = struct( ...
                'CL',[0 76 153]/255, ...
                'EL',[230 103 33]/255, ...
                'ELQ',[0 155 72]/255, ...
                'REL',[200 0 0]/255, ...
                'Neutral',[0.8 0.8 0.8], ...
                'Highlight',[0 0.45 0.74]);
            app.C.thresholds = struct('CL',4,'EL',5,'ELQ',6,'REL',[18 20]);
        end

        function buildUI(app)
            % Assemble main figure and high-level grid
            app.fig = uifigure('Name','Premier League Data Visualizations','Position',[100 100 1100 750]);
            gl = uigridlayout(app.fig,[3 2],'RowHeight',{70,'1x','2x'},'ColumnWidth',{'3x','2x'});
            app.buildHeader(gl);
            app.buildStandings(gl);
            app.buildDetails(gl);
            app.buildPlot(gl);
        end

        function buildHeader(app,parent)
            app.headerPanel = uipanel(parent); app.headerPanel.Layout.Row = 1; app.headerPanel.Layout.Column = [1 2];
            hgrid = uigridlayout(app.headerPanel,[1 6],'ColumnWidth',{160,'1x',200,150,120,70});
            uilabel(hgrid,'Text','Premier League','FontWeight','bold','FontSize',18,'HorizontalAlignment','center');
            app.segmentGroup = uibuttongroup(hgrid,'Title','View Span','TitlePosition','centertop');
            uiradiobutton(app.segmentGroup,'Text','By Seasons','Position',[10 10 110 20],'Value',true);
            uiradiobutton(app.segmentGroup,'Text','Last 10 Years','Position',[125 10 120 20]);
            % Season dropdown will list all available seasons
            app.seasonDropDown = uidropdown(hgrid,'Items',{'2018-2019','Sample-Next'},'Value',app.selectedSeason,'ValueChangedFcn',@(dd,~)app.updateSeason(dd.Value));
            uibutton(hgrid,'Text','Help','ButtonPushedFcn',@(btn,~)app.showHelp());
            uibutton(hgrid,'Text','Team Site','ButtonPushedFcn',@(b,~)app.openTeamSite());
            uilabel(hgrid,'Text',''); % spacer
        end

        function buildStandings(app,parent)
            app.standingsPanel = uipanel(parent,'Title','Standings'); app.standingsPanel.Layout.Row = 2; app.standingsPanel.Layout.Column = 1; app.standingsPanel.AutoResizeChildren = 'off';
            tgrid = uigridlayout(app.standingsPanel,[2 1],'RowHeight',{'1x',35});
            tgrid.Padding = [5 5 5 5];
            app.standingsTable = uitable(tgrid,'CellSelectionCallback',@(tbl,evt)app.tableSelection(evt),'FontSize',13);
            app.legendPanel = uipanel(tgrid); app.legendPanel.Layout.Row = 2; app.buildLegend();
            % Make table fill width by resizing columns on panel size change
            app.standingsPanel.SizeChangedFcn = @(~,~)app.autoSizeStandings();
        end

        function buildDetails(app,parent)
            app.detailsPanel = uipanel(parent,'Title','Team Details'); app.detailsPanel.Layout.Row = 2; app.detailsPanel.Layout.Column = 2;
            dgrid = uigridlayout(app.detailsPanel,[2 2],'RowHeight',{150,'1x'},'ColumnWidth',{160,'1x'});
            app.badgeImage = uiimage(dgrid,'ImageSource',''); app.badgeImage.Layout.Row = 1; app.badgeImage.Layout.Column = 1; app.badgeImage.ScaleMethod='fit';
            app.htmlDetails = uihtml(dgrid,'HTMLSource',''); app.htmlDetails.Layout.Row = 1; app.htmlDetails.Layout.Column = 2; % dynamic HTML will be injected
            % second row reserved for future extensions (stats etc.)
        end

        function buildPlot(app,parent)
            app.plotPanel = uipanel(parent,'Title','Position By MatchDay'); app.plotPanel.Layout.Row = 3; app.plotPanel.Layout.Column = [1 2];
            app.positionAxes = uiaxes(app.plotPanel); app.positionAxes.YDir='reverse'; ylabel(app.positionAxes,'Position'); xlabel(app.positionAxes,'MatchDay'); app.positionAxes.YLim=[0.5 20.5];
        end

        function buildLegend(app)
            lg = uigridlayout(app.legendPanel,[1 5],'Padding',[5 5 5 5],'ColumnWidth',{'1x','1x','1x','1x','1x'});
            makeBlock(lg,'Champions League',[0 76 153]/255);
            makeBlock(lg,'Europa League',[230 103 33]/255);
            makeBlock(lg,'Europa Qual',[0 155 72]/255);
            makeBlock(lg,'Relegated',[200 0 0]/255);
            makeBlock(lg,'Other',[0.85 0.85 0.85]);
            function makeBlock(parent,labelText,color)
                p = uipanel(parent,'BackgroundColor',color,'BorderType','none');
                lbl = uilabel(p,'Text',labelText,'HorizontalAlignment','center','FontSize',11,'FontColor','w','Position',[2 2 200 20]);
                if sum(color) > 2; lbl.FontColor = 'k'; end % dark text for light background
            end
        end

        function updateSeason(app,season)
            % Respond to season dropdown change
            try
                app.selectedSeason = season;
                key = matlab.lang.makeValidName(season);
                app.seasonData = app.data.(key);
                app.populateStandingsTable();
                app.renderPositions();
                app.updateSelection(app.selectedTeam); % refresh details
            catch ME
                uialert(app.fig,['Failed to load season: ' ME.message],'Season Error');
            end
        end

        function populateStandingsTable(app)
            % Build table from current seasonData
            s = app.seasonData.Standings;
            pts = arrayfun(@(x)x.Points,s); [~,ord] = sort(pts,'descend'); s = s(ord);
            clubs = {s.Club}'; MP=[s.MP]'; W=[s.W]'; D=[s.D]'; L=[s.L]'; GF=[s.GF]'; GA=[s.GA]'; GD=[s.GD]'; Pts=[s.Points]';
            if strcmp(app.styleMode,'html'); clubs = app.htmlColorizeRows(clubs); end
            T = table((1:numel(clubs))',clubs,MP,W,D,L,GF,GA,GD,Pts,'VariableNames',{'Pos','Club','MP','W','D','L','GF','GA','GD','Points'});
            app.standingsTable.Data = T;
            app.standingsTable.ColumnSortable = true;
            % Initial widths; autoSizeStandings will stretch to container
            app.standingsTable.ColumnWidth = {40,200,50,45,45,45,50,50,55,60};
            app.autoSizeStandings();
            if strcmp(app.styleMode,'uistyle'); app.updateTableStyles(); end
        end

        function autoSizeStandings(app)
            % Dynamically size table columns to occupy full width of standings panel
            try
                if isempty(app.standingsTable) || isempty(app.standingsTable.Data); return; end
                avail = app.standingsPanel.Position(3) - 20; % subtract padding/scrollbar
                if avail <= 200; return; end
                % Fixed widths for non-Club columns: Pos, MP, W, D, L, GF, GA, GD, Points
                fixed = [40, 50,45,45,45,50,50,55,60];
                fixedSum = sum(fixed);
                clubWidth = max(160, avail - fixedSum);
                app.standingsTable.ColumnWidth = num2cell([fixed(1) clubWidth fixed(2:end)]);
            catch
                % Gracefully ignore early layout passes
            end
        end

        function updateTableStyles(app)
            % Apply color coding to rows based on thresholds
            c = app.C.colors; th = app.C.thresholds;
            styles = {uistyle('BackgroundColor',c.CL,'FontColor','w'), ...
                      uistyle('BackgroundColor',c.EL,'FontColor','w'), ...
                      uistyle('BackgroundColor',c.ELQ,'FontColor','w'), ...
                      uistyle('BackgroundColor',c.REL,'FontColor','w')};
            addStyle(app.standingsTable,styles{1},'row',1:th.CL);
            addStyle(app.standingsTable,styles{2},'row',th.EL);
            addStyle(app.standingsTable,styles{3},'row',th.ELQ);
            addStyle(app.standingsTable,styles{4},'row',th.REL(1):th.REL(2));
        end


        function htmlClubs = htmlColorizeRows(app,clubs)
            htmlClubs = clubs;
            for i=1:numel(clubs)
                color = [1 1 1];
                if ismember(i,1:4), color=[0 76 153]/255; elseif i==5, color=[230 103 33]/255; elseif i==6, color=[0 155 72]/255; elseif ismember(i,18:20), color=[200 0 0]/255; end
                if any(color~=1)
                    hex = sprintf('#%02X%02X%02X',round(color(1)*255),round(color(2)*255),round(color(3)*255));
                    htmlClubs{i} = sprintf('<html><body style="background-color:%s;color:white;">%s</body></html>',hex,clubs{i});
                end
            end
        end

        function tableSelection(app,evt)
            % Handle row selection in standings table
            if isempty(evt.Indices); return; end
            try
                row = evt.Indices(1);
                rawClub = app.standingsTable.Data.Club{row};
                club = regexprep(rawClub,'<.*?>',''); % strip HTML
                app.updateSelection(club);
            catch ME
                uialert(app.fig,['Selection error: ' ME.message],'Selection');
            end
        end

        function updateSelection(app,club)
            % Update selected team and details panel
            try
                app.selectedTeam = club;
                % Attempt to fetch and display team badge from TheSportsDB
                badgeUrl = app.getBadgeUrlForTeam(club);
                if ~isempty(badgeUrl)
                    app.setBadgeFromUrl(badgeUrl);
                else
                    app.badgeImage.ImageSource = '';
                end
                app.updateTeamDetailsHTML();
                app.renderPositions(); % re-highlight plot
            catch ME
                uialert(app.fig,['Failed to update team details: ' ME.message],'Team Error');
            end
        end

        function setBadgeFromUrl(app,url)
            % Set badge image by downloading and loading image data
            try
                if isempty(url)
                    app.badgeImage.ImageSource = '';
                    return;
                end
                % Download image data using webread with options
                opts = weboptions('Timeout', 10, 'ContentType', 'binary');
                imgData = webread(url, opts);
                % Write to temporary file and read back
                [~, ~, ext] = fileparts(url);
                if isempty(ext) || ~startsWith(ext, '.'); ext = '.png'; end
                tempFile = [tempname ext];
                fid = fopen(tempFile, 'wb');
                fwrite(fid, imgData, 'uint8');
                fclose(fid);
                % Load image and set
                img = imread(tempFile);
                app.badgeImage.ImageSource = img;
                % Clean up temp file
                delete(tempFile);
            catch
                % Fallback: try direct URL (works in newer MATLAB)
                try
                    app.badgeImage.ImageSource = url;
                catch
                    app.badgeImage.ImageSource = '';
                end
            end
        end

        function url = getBadgeUrlForTeam(app,club)
            % Query TheSportsDB for a team's badge URL (strBadge)
            % Uses a small mapping to canonical names and caches results
            import matlab.net.URI
            import matlab.net.QueryParameter
            url = '';
            try
                name = app.canonicalTeamName(club);
                if isKey(app.badgeCache,name)
                    url = app.badgeCache(name); return; 
                end
                base = URI('https://www.thesportsdb.com/api/v1/json');
                base.Path(end+1) = app.sportsDbApiKey; %#ok<AGROW>
                base.Path(end+1) = 'searchteams.php'; %#ok<AGROW>
                base.Query = QueryParameter('t',name);
                resp = webread(string(base));
                if isstruct(resp) && isfield(resp,'teams') && ~isempty(resp.teams)
                    rec = resp.teams(1);
                    if isfield(rec,'strBadge') && ~isempty(rec.strBadge)
                        badgeUrl = strtrim(rec.strBadge);
                        % Validate URL is complete (has file extension)
                        if contains(badgeUrl, '.') && (startsWith(badgeUrl, 'http://') || startsWith(badgeUrl, 'https://'))
                            url = badgeUrl;
                            app.badgeCache(name) = url;
                        end
                    end
                end
            catch
                % Ignore errors (offline or API down). Badge will remain blank.
            end
        end

        function name = canonicalTeamName(~,club)
            % Map dataset names to common official names for API queries
            switch strtrim(club)
                case 'Man City',      name = 'Manchester City';
                case 'Man United',    name = 'Manchester United';
                case 'Wolves',        name = 'Wolverhampton Wanderers';
                case 'West Ham',      name = 'West Ham United';
                case 'Leicester',     name = 'Leicester City';
                case 'Newcastle',     name = 'Newcastle United';
                case 'Bournemouth',   name = 'AFC Bournemouth';
                case 'Brighton',      name = 'Brighton & Hove Albion';
                case 'Huddersfield',  name = 'Huddersfield Town';
                case 'Cardiff',       name = 'Cardiff City';
                otherwise,            name = club;
            end
        end

        function updateTeamDetailsHTML(app)
            % Compose HTML snippet for team details (cards + last 10 results)
            club = app.selectedTeam; c = app.seasonData.Cards.(matlab.lang.makeValidName(club));
            rseq = app.seasonData.Results.(matlab.lang.makeValidName(club));
            blockHTML = "";
            for i=1:numel(rseq)
                switch rseq(i)
                    case 2, col='#008f2b'; txt='W';
                    case 1, col='#777777'; txt='D';
                    otherwise, col='#b00000'; txt='L';
                end
                blockHTML = blockHTML + sprintf('<div class="res" style="background:%s">%s</div>',col,txt);
            end
            html = sprintf([ ...
                '<html><head><style>' ...
                'body{font-family:Arial,sans-serif;padding:8px;margin:0;}' ...
                '.title{font-size:20px;font-weight:bold;margin-bottom:10px;color:#000;}' ...
                '.cards{margin:10px 0 12px 0;font-size:13px;color:#333;}' ...
                '.cards b{color:#000;}' ...
                '.label{font-size:11px;color:#666;margin-bottom:4px;}' ...
                '.res{width:26px;height:26px;display:inline-flex;justify-content:center;align-items:center;color:#fff;font-weight:bold;margin-right:3px;border-radius:3px;font-size:12px;box-shadow:0 1px 2px rgba(0,0,0,0.1);}' ...
                '</style></head><body>' ...
                '<div class="title">%s</div>' ...
                '<div class="cards">Red: <b>%d</b> | Yellow: <b>%d</b></div>' ...
                '<div class="label">W/D/L trend in last 10 Matches</div>' ...
                '<div>%s</div>' ...
                '</body></html>'],club,c.Red,c.Yellow,blockHTML);
            app.htmlDetails.HTMLSource = html;
        end

        function renderPositions(app)
            % Plot position trajectories highlighting selected team
            cla(app.positionAxes); hold(app.positionAxes,'on');
            posMatrix = app.seasonData.Positions; mdays = 1:app.seasonData.Matchdays; clubs = {app.seasonData.Standings.Club};
            pts = arrayfun(@(x)x.Points, app.seasonData.Standings); [~,ord] = sort(pts,'descend'); clubs = clubs(ord); posMatrix = posMatrix(ord,:);
            % Draw neutral teams first
            for i=1:numel(clubs)
                if ~strcmp(clubs{i},app.selectedTeam)
                    plot(app.positionAxes, mdays, posMatrix(i,:),'-','Color',[0.82 0.82 0.82],'LineWidth',0.6);
                end
            end
            % Draw selected team on top
            for i=1:numel(clubs)
                if strcmp(clubs{i},app.selectedTeam)
                    colHighlight = app.C.colors.Highlight;
                    plot(app.positionAxes, mdays, posMatrix(i,:),'-o','Color',colHighlight,'MarkerFaceColor',colHighlight,'MarkerSize',4,'LineWidth',2.5);
                    text(app.positionAxes, mdays(end)+0.5, posMatrix(i,end), clubs{i},'Color',colHighlight,'FontWeight','bold','FontSize',11);
                    break;
                end
            end
            app.positionAxes.YLim=[0.5 20.5]; app.positionAxes.XLim=[0.5 mdays(end)+0.5];
            app.positionAxes.YGrid='on'; app.positionAxes.XGrid='on';
            app.positionAxes.GridAlpha = 0.15; app.positionAxes.FontSize = 10;
            title(app.positionAxes,'Position By MatchDay','FontSize',12); hold(app.positionAxes,'off');
        end

        function openTeamSite(app)
            % Simple mapping; extend as needed.
            urls = struct('ManCity','https://www.mancity.com','Liverpool','https://www.liverpoolfc.com');
            fn = matlab.lang.makeValidName(strrep(app.selectedTeam,' ','')); % Remove spaces
            if isfield(urls,fn)
                web(urls.(fn),'-browser');
            else
                web('https://www.premierleague.com','-browser');
            end
        end

        function showHelp(app)
            uialert(app.fig,'Select a team in the table to view details, cards, and recent form. Extend seasons by editing loadData().','Help');
        end
    end
end
