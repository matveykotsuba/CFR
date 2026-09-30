function results = cfrRun(targetPaprDb, seed, showPlots)
    if nargin < 1 || isempty(targetPaprDb)
        targetPaprDb = 7.5;
    end
    if nargin < 2 || isempty(seed)
        seed = 7;
    end
    if nargin < 3 || isempty(showPlots)
        showPlots = true;
    end
    validateattributes(targetPaprDb, {'numeric'}, {'scalar', 'real', 'finite', 'positive'});
    validateattributes(seed, {'numeric'}, {'scalar', 'real', 'finite', 'integer', 'nonnegative', '<=', 2^32-1});
    validateattributes(showPlots, {'logical', 'numeric'}, {'scalar', 'real', 'finite', 'binary'});

    cfg = cfrSystemConfig(false);
    [inputSignal, txInfo] = tx(cfg, seed, false);
    cfg.cfr.enabled = true;
    cfg.cfr.targetPaprDb = targetPaprDb;
    [outputSignal, cfrInfo] = cfrCore(inputSignal, cfg.cfr, cfg);

    results.cfg = cfg;
    results.seed = seed;
    results.inputSignal = inputSignal;
    results.outputSignal = outputSignal;
    results.inputPaprDb = cfrInfo.inputPaprDb;
    results.outputPaprDb = cfrInfo.outputPaprDb;
    results.paprReductionDb = cfrInfo.paprReductionDb;
    results.cfrOnlyEvmPercent = cfrInfo.cfrOnlyEvmPercent;
    results.cfrInfo = cfrInfo;
    results.txInfo = txInfo;
    results.figures.peaks = [];
    results.figures.cdfBefore = [];
    results.figures.cdfAfter = [];

    if showPlots
        results.figures.peaks = cfrPeakCancellationPlot(cfrInfo, cfg.cfr);
        upperLimit = max(10, ceil(max(cfrInfo.inputPaprDb, cfrInfo.outputPaprDb)) + 1);
        results.figures.cdfBefore = powerCdf(inputSignal, cfrInfo.inputPaprDb, 'CFR OFF', upperLimit);
        results.figures.cdfAfter = powerCdf(outputSignal, cfrInfo.outputPaprDb, 'CFR ON', upperLimit);
    end

    fprintf('\nCFR target: %.2f dB.\n', targetPaprDb);
    fprintf('Frame PAPR: %.4f -> %.4f dB, reduction %.4f dB.\n', results.inputPaprDb, results.outputPaprDb, results.paprReductionDb);
    fprintf('CFR-only gain-corrected waveform EVM: %.4f %%.\n', results.cfrOnlyEvmPercent);
    fprintf('Cancellation pulses: %d, average power change: %.3g dB.\n', cfrInfo.totalPulseCount, cfrInfo.averagePowerChangeDb);
end

function figureHandle = powerCdf(signal, paprDb, label, upperLimit)
    power = abs(signal(:)).^2;
    relativePowerDb = 10 * log10(max(power / mean(power), realmin('double')));
    sortedPowerDb = sort(relativePowerDb);
    probability = (1:length(sortedPowerDb)).' / length(sortedPowerDb);
    figureHandle = figure('Name', ['OFDM power CDF, ' label], 'NumberTitle', 'off', 'Color', 'w');
    stairs(sortedPowerDb, probability, 'b', 'LineWidth', 1.0);
    grid on;
    xlabel('Instantaneous power relative to average, dB');
    ylabel('Cumulative probability');
    title(sprintf('OFDM CDF, %s, PAPR = %.2f dB', label, paprDb));
    xlim([-70 upperLimit]);
    ylim([0 1]);
end
