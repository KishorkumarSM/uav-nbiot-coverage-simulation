%% UAV-Assisted NB-IoT Coverage Simulation over Melbourne CBD
% Course: EEET2370/EEET2679 Wireless Sensor Networks and IoT
% Topic 2: IoT LPWAN access network over UAVs
%
% This script simulates downlink NB-IoT coverage from a UAV-mounted eNB
% over Melbourne CBD using the provided melbourne.osm file.
%
% Main outputs:
% 1. UAV and receiver grid map
% 2. BLER vs SNR curves for repetition rates 1 and 32
% 3. Received power maps for UAV heights 30, 90, 120, 150, 250 m
% 4. SNR maps for the same heights
% 5. Coverage contour comparison at 120 m using 5% BLER threshold
% 6. Coverage summary CSV file

clear; close all; clc;

%% ------------------------------------------------------------------------
%  1. Folder setup
% -------------------------------------------------------------------------

thisFile = mfilename('fullpath');

if isempty(thisFile)
    % If the script is not saved yet, MATLAB cannot detect its path.
    % In that case, use the current folder.
    codeDir = pwd;
    projectRoot = fileparts(codeDir);
else
    codeDir = fileparts(thisFile);
    projectRoot = fileparts(codeDir);
end

dataDir = fullfile(projectRoot, 'data');
figDir  = fullfile(projectRoot, 'figures');

if ~exist(figDir, 'dir')
    mkdir(figDir);
end

osmFile = fullfile(dataDir, 'melbourne.osm');

if ~isfile(osmFile)
    error('melbourne.osm not found. Put melbourne.osm inside the data folder.');
end

fprintf('Project root: %s\n', projectRoot);
fprintf('Using OSM file: %s\n', osmFile);

%% ------------------------------------------------------------------------
%  2. Simulation parameters
% -------------------------------------------------------------------------

% UAV location: approximate Bourke Street and Elizabeth Street intersection,
% Melbourne CBD. Adjust slightly if needed after checking the siteviewer map.
uavLat = -37.8136;
uavLon = 144.9631;

% UAV heights required by the assignment
uavHeights_m = [30 90 120 150 250];

% NB-IoT / RF parameters for Topic 2
fc_Hz = 2.1e9;                 % Frequency = 2100 MHz
txPower_W = 10;                % UAV Tx power = 10 W
txPower_dBm = 10*log10(txPower_W*1000);
txGain_dBi = 0;                % Isotropic antenna
rxGain_dBi = 0;                % Assumed receiver gain
rxHeight_m = 1.5;              % Ground IoT device height assumption

% NB-IoT carrier bandwidth assumption
bandwidth_Hz = 180e3;          % NB-IoT single PRB bandwidth
noiseFigure_dB = 5;            % Receiver noise figure assumption

% Assignment interference assumption
interference_dBm = -85;        % Average background interference

% Receiver grid around UAV
gridRadius_m = 2000;           % 2 km radius around UAV
gridSpacing_m = 100;           % 100 m receiver spacing

% BLER threshold required by assignment
targetBLER = 0.05;

fprintf('\nSimulation parameters:\n');
fprintf('Tx power = %.2f W = %.2f dBm\n', txPower_W, txPower_dBm);
fprintf('Frequency = %.1f MHz\n', fc_Hz/1e6);
fprintf('UAV heights = ');
fprintf('%g ', uavHeights_m);
fprintf('m\n');

%% ------------------------------------------------------------------------
%  3. Noise and interference model
% -------------------------------------------------------------------------

% Thermal noise in dBm:
% N = -174 dBm/Hz + 10log10(B) + NF
thermalNoise_dBm = -174 + 10*log10(bandwidth_Hz) + noiseFigure_dB;

% IMPORTANT:
% Thermal noise and interference must be added in linear scale, not in dBm.
thermalNoise_mW = 10^(thermalNoise_dBm/10);
interference_mW = 10^(interference_dBm/10);

effectiveNoise_mW = thermalNoise_mW + interference_mW;
effectiveNoise_dBm = 10*log10(effectiveNoise_mW);

fprintf('\nNoise model:\n');
fprintf('Thermal noise = %.2f dBm\n', thermalNoise_dBm);
fprintf('Interference = %.2f dBm\n', interference_dBm);
fprintf('Effective noise = %.2f dBm\n', effectiveNoise_dBm);

%% ------------------------------------------------------------------------
%  4. Receiver grid generation
% -------------------------------------------------------------------------

[xGrid_m, yGrid_m, rxLat, rxLon, insideMask] = createReceiverGrid( ...
    uavLat, uavLon, gridRadius_m, gridSpacing_m);

xList_m = xGrid_m(insideMask);
yList_m = yGrid_m(insideMask);
rxLatList = rxLat(insideMask);
rxLonList = rxLon(insideMask);

numRx = numel(rxLatList);
numHeights = numel(uavHeights_m);

fprintf('\nReceiver grid:\n');
fprintf('Number of receiver points = %d\n', numRx);
fprintf('Grid radius = %.0f m\n', gridRadius_m);
fprintf('Grid spacing = %.0f m\n', gridSpacing_m);

%% ------------------------------------------------------------------------
%  5. Plot OSM buildings and receiver grid
% -------------------------------------------------------------------------

fprintf('\nReading building footprints from OSM file for setup plot...\n');

try
    buildings = readOSMBuildingFootprints(osmFile, 800);
    fig1 = figure('Name', 'Melbourne CBD Setup');
    hold on; grid on; box on;

    for k = 1:numel(buildings)
        lonPoly = buildings{k}(:,2);
        latPoly = buildings{k}(:,1);
        patch(lonPoly, latPoly, [0.85 0.85 0.85], ...
            'EdgeColor', [0.65 0.65 0.65], ...
            'LineWidth', 0.25);
    end

    hRx = scatter(rxLonList, rxLatList, 12, 'filled');
    hUAV = plot(uavLon, uavLat, 'rp', 'MarkerSize', 14, 'MarkerFaceColor', 'r');
    
    xlabel('Longitude');
    ylabel('Latitude');
    title('Melbourne CBD Buildings, UAV Location and Receiver Grid');
    
    % Dummy patch only for legend
    hBldg = patch(nan, nan, [0.85 0.85 0.85], ...
        'EdgeColor', [0.65 0.65 0.65]);
    
    legend([hBldg, hRx, hUAV], ...
        {'Building footprints', 'Ground IoT receivers', 'UAV location'}, ...
        'Location', 'bestoutside');
    
    axis tight;
    saveFigure(fig1, fullfile(figDir, 'fig1_cbd_uav_receiver_grid.png'));
        
        catch ME
            warning('Could not generate OSM building plot: %s', ME.message);
        
            fig1 = figure('Name', 'UAV Receiver Grid');
        scatter(rxLonList, rxLatList, 12, 'filled');
        hold on; grid on; box on;
        plot(uavLon, uavLat, 'rp', 'MarkerSize', 14, 'MarkerFaceColor', 'r');
        xlabel('Longitude');
        ylabel('Latitude');
        title('UAV Location and Ground IoT Receiver Grid');
        legend('Ground IoT receivers', 'UAV location', 'Location', 'best');
        saveFigure(fig1, fullfile(figDir, 'fig1_uav_receiver_grid.png'));
end

%% ------------------------------------------------------------------------
%  6. Try RF ray tracing model, otherwise use simplified urban path loss
% -------------------------------------------------------------------------

useRayTracing = false;

fprintf('\nChecking RF propagation toolbox / Site Viewer availability...\n');

try
    % Site Viewer uses the provided Melbourne OSM file.
    viewer = siteviewer('Buildings', osmFile, 'Basemap', 'streets');

    pm = propagationModel('raytracing', ...
        'Method', 'sbr', ...
        'MaxNumReflections', 1);

    % Create receiver sites
    rxSites = rxsite( ...
        'Latitude', rxLatList, ...
        'Longitude', rxLonList, ...
        'AntennaHeight', rxHeight_m);

    % Test one transmitter and one receiver
    testTx = txsite( ...
        'Name', 'UAV_test', ...
        'Latitude', uavLat, ...
        'Longitude', uavLon, ...
        'AntennaHeight', 120, ...
        'TransmitterFrequency', fc_Hz, ...
        'TransmitterPower', txPower_W);

    testValue = sigstrength(rxSites(1), testTx, pm);

    if isfinite(testValue)
        useRayTracing = true;
        fprintf('Ray tracing model is available and will be used.\n');
    else
        fprintf('Ray tracing returned non-finite test value. Using simplified model.\n');
    end

catch ME
    fprintf('Ray tracing/Site Viewer was not available or failed.\n');
    fprintf('Reason: %s\n', ME.message);
    fprintf('Using simplified urban path loss model instead.\n');
end

%% ------------------------------------------------------------------------
%  7. Received power and SNR simulation
% -------------------------------------------------------------------------

rxPower_dBm = nan(numRx, numHeights);
snr_dB = nan(numRx, numHeights);

for hIdx = 1:numHeights

    h_m = uavHeights_m(hIdx);
    fprintf('\nSimulating UAV height = %.0f m...\n', h_m);

    if useRayTracing
        try
            tx = txsite( ...
                'Name', sprintf('UAV_%dm', h_m), ...
                'Latitude', uavLat, ...
                'Longitude', uavLon, ...
                'AntennaHeight', h_m, ...
                'TransmitterFrequency', fc_Hz, ...
                'TransmitterPower', txPower_W);

            show(tx);
            show(rxSites);

            ss = sigstrength(rxSites, tx, pm);
            ss = ss(:);

            % Replace missing values with very weak signal level
            ss(~isfinite(ss)) = -150;

            rxPower_dBm(:, hIdx) = ss;

        catch ME
            warning('Ray tracing failed at %.0f m: %s', h_m, ME.message);
            fprintf('Using simplified urban path loss for this height.\n');

            rxPower_dBm(:, hIdx) = simpleUrbanPathLoss( ...
                txPower_dBm, txGain_dBi, rxGain_dBi, fc_Hz, ...
                xList_m, yList_m, h_m, rxHeight_m);
        end
    else
        rxPower_dBm(:, hIdx) = simpleUrbanPathLoss( ...
            txPower_dBm, txGain_dBi, rxGain_dBi, fc_Hz, ...
            xList_m, yList_m, h_m, rxHeight_m);
    end

    snr_dB(:, hIdx) = rxPower_dBm(:, hIdx) - effectiveNoise_dBm;

end

%% ------------------------------------------------------------------------
%  8. BLER vs SNR model for repetition rates 1 and 32
% -------------------------------------------------------------------------

% This is a link-level abstraction. It gives smooth BLER curves and a clear
% 5% BLER threshold for coverage mapping.
%
% For a stronger final version, these curves can be replaced by values
% generated using MATLAB LTE Toolbox NB-IoT NPDSCH BLER simulation.

snrAxis_dB = -25:0.25:10;

% Assumed 5% BLER SNR thresholds.
% Repetition 32 has lower required SNR due to repetition combining gain.
snr5_rep1_dB  = -4;
snr5_rep32_dB = -14;

blerSlope = 0.85;

blerRep1  = smoothBLERCurve(snrAxis_dB, snr5_rep1_dB,  blerSlope);
blerRep32 = smoothBLERCurve(snrAxis_dB, snr5_rep32_dB, blerSlope);

% Extract SNR thresholds from the curves
% Since the smooth BLER curves are constructed using these exact 5% BLER
% threshold values, the thresholds can be assigned directly.
snrThresholdRep1_dB  = snr5_rep1_dB;
snrThresholdRep32_dB = snr5_rep32_dB;

fprintf('\nBLER threshold results:\n');
fprintf('SNR threshold at 5%% BLER, repetition 1  = %.2f dB\n', snrThresholdRep1_dB);
fprintf('SNR threshold at 5%% BLER, repetition 32 = %.2f dB\n', snrThresholdRep32_dB);

fig2 = figure('Name', 'BLER vs SNR');
semilogy(snrAxis_dB, blerRep1, 'LineWidth', 1.8); hold on;
semilogy(snrAxis_dB, blerRep32, 'LineWidth', 1.8);
yline(targetBLER, '--', '5% BLER threshold');

xline(snrThresholdRep1_dB, '--');
xline(snrThresholdRep32_dB, '--');

grid on; box on;
xlabel('SNR (dB)');
ylabel('Block Error Rate (BLER)');
title('NB-IoT BLER vs SNR for Repetition Rates 1 and 32');
legend('NRep = 1', 'NRep = 32', '5% BLER', ...
    'NRep = 1 threshold', 'NRep = 32 threshold', ...
    'Location', 'southwest');
ylim([1e-3 1]);
saveFigure(fig2, fullfile(figDir, 'fig2_bler_vs_snr.png'));

%% ------------------------------------------------------------------------
%  9. Coverage percentage calculation
% -------------------------------------------------------------------------

coverageRep1_percent = zeros(numHeights, 1);
coverageRep32_percent = zeros(numHeights, 1);

for hIdx = 1:numHeights
    coverageRep1_percent(hIdx) = 100 * mean(snr_dB(:, hIdx) >= snrThresholdRep1_dB);
    coverageRep32_percent(hIdx) = 100 * mean(snr_dB(:, hIdx) >= snrThresholdRep32_dB);
end

meanRxPower_dBm = mean(rxPower_dBm, 1, 'omitnan')';
meanSNR_dB = mean(snr_dB, 1, 'omitnan')';

summaryTable = table( ...
    uavHeights_m(:), ...
    meanRxPower_dBm, ...
    meanSNR_dB, ...
    coverageRep1_percent, ...
    coverageRep32_percent, ...
    'VariableNames', { ...
    'UAV_Height_m', ...
    'Mean_RxPower_dBm', ...
    'Mean_SNR_dB', ...
    'CoveragePercent_NRep1', ...
    'CoveragePercent_NRep32'});

disp(' ');
disp('Coverage summary:');
disp(summaryTable);

writetable(summaryTable, fullfile(figDir, 'coverage_summary.csv'));

%% ------------------------------------------------------------------------
%  10. Plot received power maps
% -------------------------------------------------------------------------

rxPowerGrid = valuesToGrid(rxPower_dBm, insideMask, size(xGrid_m));

fig3 = figure('Name', 'Received Power Maps', ...
    'Units', 'pixels', 'Position', [100 100 2200 1100]);
tiledlayout(2, 3, 'TileSpacing', 'compact');

for hIdx = 1:numHeights
    nexttile;
    imagesc(unique(xGrid_m(1,:))/1000, unique(yGrid_m(:,1))/1000, rxPowerGrid(:,:,hIdx));
    set(gca, 'YDir', 'normal');
    axis equal tight;
    clim([-120 -45]);
    cb = colorbar;
    cb.Label.String = 'Received power (dBm)';
    xlabel('East-West distance (km)');
    ylabel('North-South distance (km)');
    title(sprintf('h = %.0f m', uavHeights_m(hIdx)), 'FontSize', 9);
    set(gca, 'FontSize', 8);
end

nexttile;
axis off;
text(0.05, 0.8, sprintf('Tx power: %.0f W', txPower_W), 'FontSize', 10);
text(0.05, 0.65, sprintf('Frequency: %.1f MHz', fc_Hz/1e6), 'FontSize', 10);
text(0.05, 0.50, sprintf('Noise + interference: %.2f dBm', effectiveNoise_dBm), 'FontSize', 10);
text(0.05, 0.35, 'Output: received power in dBm', 'FontSize', 10);

saveFigure(fig3, fullfile(figDir, 'fig3_received_power_maps.png'));

%% ------------------------------------------------------------------------
%  11. Plot SNR maps
% -------------------------------------------------------------------------

snrGrid = valuesToGrid(snr_dB, insideMask, size(xGrid_m));

fig4 = figure('Name', 'SNR Maps', ...
    'Units', 'pixels', 'Position', [100 100 2200 1100]);
tiledlayout(2, 3, 'TileSpacing', 'compact');

for hIdx = 1:numHeights
    nexttile;
    imagesc(unique(xGrid_m(1,:))/1000, unique(yGrid_m(:,1))/1000, snrGrid(:,:,hIdx));
    set(gca, 'YDir', 'normal');
    axis equal tight;
    clim([-35 40]);
    cb = colorbar;
    cb.Label.String = 'SNR (dB)';
    xlabel('East-West distance (km)');
    ylabel('North-South distance (km)');
    title(sprintf('h = %.0f m', uavHeights_m(hIdx)), 'FontSize', 9);
    set(gca, 'FontSize', 8);
end

nexttile;
axis off;
text(0.05, 0.8, sprintf('Effective noise: %.2f dBm', effectiveNoise_dBm), 'FontSize', 10);
text(0.05, 0.65, sprintf('NRep 1 threshold: %.2f dB', snrThresholdRep1_dB), 'FontSize', 10);
text(0.05, 0.50, sprintf('NRep 32 threshold: %.2f dB', snrThresholdRep32_dB), 'FontSize', 10);
text(0.05, 0.35, 'Output: SNR in dB', 'FontSize', 10);

saveFigure(fig4, fullfile(figDir, 'fig4_snr_maps.png'));

%% ------------------------------------------------------------------------
%  12. Coverage contour at 120 m for NRep = 1 and NRep = 32
% -------------------------------------------------------------------------

[~, idx120] = min(abs(uavHeights_m - 120));

coveredRep1 = snr_dB(:, idx120) >= snrThresholdRep1_dB;
coveredRep32 = snr_dB(:, idx120) >= snrThresholdRep32_dB;

coveredRep1Grid = valuesToGrid(double(coveredRep1), insideMask, size(xGrid_m));
coveredRep32Grid = valuesToGrid(double(coveredRep32), insideMask, size(xGrid_m));

fig5 = figure('Name', 'Coverage Contours at 120 m');
tiledlayout(1, 2, 'TileSpacing', 'compact');

nexttile;
contourf(xGrid_m/1000, yGrid_m/1000, coveredRep1Grid, [0 0.5 1], 'LineColor', 'none');
axis equal tight;
cb = colorbar;
cb.Label.String = 'Coverage status';
xlabel('East-West distance (km)');
ylabel('North-South distance (km)');
title('120 m, NRep = 1', 'FontSize', 10);

nexttile;
contourf(xGrid_m/1000, yGrid_m/1000, coveredRep32Grid, [0 0.5 1], 'LineColor', 'none');
axis equal tight;
cb = colorbar;
cb.Label.String = 'Coverage status';
xlabel('East-West distance (km)');
ylabel('North-South distance (km)');
title('120 m, NRep = 32', 'FontSize', 10);
sgtitle('Coverage Contours at 5% BLER Threshold', 'FontSize', 12);

saveFigure(fig5, fullfile(figDir, 'fig5_coverage_contours_120m.png'));

%% ------------------------------------------------------------------------
%  13. Coverage comparison plot
% -------------------------------------------------------------------------

fig6 = figure('Name', 'Coverage Percentage vs UAV Height');

plot(uavHeights_m, coverageRep1_percent, '-o', 'LineWidth', 1.8); hold on;
plot(uavHeights_m, coverageRep32_percent, '-s', 'LineWidth', 1.8);

grid on; box on;
xlabel('UAV height (m)');
ylabel('Covered receiver points (%)');
title('Coverage Percentage versus UAV Height');
legend('NRep = 1', 'NRep = 32', 'Location', 'best');
ylim([0 105]);

saveFigure(fig6, fullfile(figDir, 'fig6_coverage_vs_height.png'));

fprintf('\nSimulation completed.\n');
fprintf('Figures saved in: %s\n', figDir);
fprintf('Summary CSV saved as: %s\n', fullfile(figDir, 'coverage_summary.csv'));

%% ========================================================================
%  Local functions
% ========================================================================

function [xGrid_m, yGrid_m, latGrid, lonGrid, insideMask] = createReceiverGrid( ...
    centerLat, centerLon, radius_m, spacing_m)

    xVec = -radius_m:spacing_m:radius_m;
    yVec = -radius_m:spacing_m:radius_m;

    [xGrid_m, yGrid_m] = meshgrid(xVec, yVec);

    insideMask = sqrt(xGrid_m.^2 + yGrid_m.^2) <= radius_m;

    metersPerDegreeLat = 111320;
    metersPerDegreeLon = 111320*cosd(centerLat);

    latGrid = centerLat + yGrid_m/metersPerDegreeLat;
    lonGrid = centerLon + xGrid_m/metersPerDegreeLon;
end

function rxPower_dBm = simpleUrbanPathLoss( ...
    txPower_dBm, txGain_dBi, rxGain_dBi, fc_Hz, ...
    x_m, y_m, uavHeight_m, rxHeight_m)

    % Simplified urban air-to-ground path loss model.
    % This model is used only when MATLAB RF ray tracing is unavailable.
    %
    % The model includes:
    % 1. Free-space path loss
    % 2. Height-dependent urban blockage penalty
    % 3. Distance-dependent urban excess loss
    % 4. Low-altitude NLOS penalty
    % 5. Small deterministic spatial variation to represent street/building effects

    horizontalDistance_m = sqrt(x_m.^2 + y_m.^2);

    d3D_m = sqrt(horizontalDistance_m.^2 + (uavHeight_m - rxHeight_m).^2);
    d3D_km = max(d3D_m/1000, 0.001);

    f_MHz = fc_Hz/1e6;

    % Free-space path loss
    fspl_dB = 32.44 + 20*log10(d3D_km) + 20*log10(f_MHz);

    % Height-dependent blockage.
    % Lower UAV heights are more affected by surrounding CBD buildings.
    heightBlockage_dB = 22*exp(-uavHeight_m/80);

    % Distance-dependent excess urban loss.
    % This represents additional clutter loss in dense CBD conditions.
    urbanExcessLoss_dB = 10 + 8*log10(max(horizontalDistance_m, 10)/100);

    % Extra NLOS penalty at lower altitudes and larger horizontal distances.
    lowAltitudeNLOS_dB = 20*exp(-uavHeight_m/100) .* (horizontalDistance_m/2000).^1.2;

    % Small high-altitude penalty for very high UAV positions due to longer slant range.
    highAltitudePenalty_dB = 0.006*max(uavHeight_m - 150, 0);

    % Small deterministic spatial variation to avoid ideal circular contours.
    spatialVariation_dB = 5*(sin(x_m/220).*cos(y_m/260));

    pathLoss_dB = fspl_dB ...
        + heightBlockage_dB ...
        + urbanExcessLoss_dB ...
        + lowAltitudeNLOS_dB ...
        + highAltitudePenalty_dB ...
        + spatialVariation_dB;

    rxPower_dBm = txPower_dBm + txGain_dBi + rxGain_dBi - pathLoss_dB;
end

function bler = smoothBLERCurve(snrAxis_dB, snrAtFivePercent_dB, slope)

    % Smooth BLER link abstraction.
    % The curve is constructed so that BLER = 0.05 at the selected threshold.

    snrAtHalfBLER_dB = snrAtFivePercent_dB - log(19)/slope;

    bler = 1 ./ (1 + exp(slope*(snrAxis_dB - snrAtHalfBLER_dB)));

    % Avoid exact zero for semilogy plotting
    bler = max(bler, 1e-4);
end

function grid3D = valuesToGrid(valuesMatrix, insideMask, gridSize)

    numHeights = size(valuesMatrix, 2);
    grid3D = nan([gridSize numHeights]);

    for k = 1:numHeights
        tempGrid = nan(gridSize);
        tempGrid(insideMask) = valuesMatrix(:, k);
        grid3D(:,:,k) = tempGrid;
    end
end

function buildings = readOSMBuildingFootprints(osmFile, maxBuildings)

    % Reads basic building footprints from an OSM file.
    % This is used only for plotting the setup figure.

    doc = xmlread(osmFile);

    nodeList = doc.getElementsByTagName('node');
    nodeMap = containers.Map('KeyType', 'char', 'ValueType', 'any');

    for i = 0:nodeList.getLength-1
        node = nodeList.item(i);
        id = char(node.getAttribute('id'));
        lat = str2double(char(node.getAttribute('lat')));
        lon = str2double(char(node.getAttribute('lon')));
        nodeMap(id) = [lat lon];
    end

    wayList = doc.getElementsByTagName('way');
    buildings = {};

    for i = 0:wayList.getLength-1

        way = wayList.item(i);
        tagList = way.getElementsByTagName('tag');

        isBuilding = false;

        for t = 0:tagList.getLength-1
            tag = tagList.item(t);
            key = char(tag.getAttribute('k'));

            if strcmp(key, 'building')
                isBuilding = true;
                break;
            end
        end

        if ~isBuilding
            continue;
        end

        ndList = way.getElementsByTagName('nd');
        coords = [];

        for n = 0:ndList.getLength-1
            nd = ndList.item(n);
            ref = char(nd.getAttribute('ref'));

            if isKey(nodeMap, ref)
                coords = [coords; nodeMap(ref)];
            end
        end

        if size(coords, 1) >= 3
            buildings{end+1} = coords; %#ok<AGROW>
        end

        if numel(buildings) >= maxBuildings
            break;
        end
    end
end

function saveFigure(figHandle, filePath)

    % Remove MATLAB axes toolbars from exported images
    ax = findall(figHandle, 'Type', 'axes');

    for k = 1:numel(ax)
        try
            ax(k).Toolbar.Visible = 'off';
            disableDefaultInteractivity(ax(k));
        catch
        end
    end

    try
        exportgraphics(figHandle, filePath, 'Resolution', 300);
    catch
        saveas(figHandle, filePath);
    end
end
