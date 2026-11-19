function waitForFigureLayout(fig)
% waitForFigureLayout Dispatch the browser wait and receive its result on the figure ViewModel.
arguments (Input)
    fig (1, 1) matlab.ui.Figure
end
% Find the browser window that hosts the figure.
% struct() reads every hidden property, so besides MATLAB:structOnObject it can
% emit unrelated deprecation warnings (JavaFrame, GraphicsSmoothing, ...).
% Silence all warnings only for these three calls.
warningState = warning("off", "all");
warningCleanup = onCleanup(@() warning(warningState));
figureData = struct(fig);
controller = struct(figureData.Controller);
host = struct(controller.PlatformHost);
clear warningCleanup
assert(isfield(host, "CEF") && ~isempty(host.CEF), ...
    "This figure has no CEF window. Use uifigure through R2024b. " + ...
    "In R2025a or later, create the figure with matlab.ui.internal.uifigureIsolated.");
viewModel = controller.ViewModel;

% Use a unique completion event for this request and subscribe before dispatch.
requestId = erase(string(java.util.UUID.randomUUID()), "-");
eventName = "FigureLayoutWaitCompleted_" + requestId;
reply = [];
listener = viewModel.addEventListener(char(eventName), @receive);
listenerCleanup = onCleanup(@() delete(listener));
configuration = struct("figureId", string(viewModel.getId()), ...
    "channel", string(matlab.ui.internal.FigureServices.getUniqueChannelId(fig)), ...
    "eventName", eventName);
source = fileread(fullfile(fileparts(mfilename("fullpath")), "waitForFigureLayout.js"));
script = replace(string(source), "__LAYOUT_WAIT_CONFIGURATION__", string(jsonencode(configuration)));
host.CEF.executeJS(char(script), 10);

% Yield to MATLAB callbacks and bound the wait for a missing browser reply.
clock = tic;
while isempty(reply) && toc(clock) < 8
    pause(0.01);
end
assert(~isempty(reply), "Timed out waiting for the figure ViewModel reply.");
if isfield(reply, "error")
    error("Browser layout wait failed: %s", string(reply.error));
end
clear listenerCleanup

    function receive(~, event)
    % receive Store the payload for this request's completion event.
        reply = event.data;
    end
end

%{
Copyright (C) 2026 Nobuto Kaitoh

This file is part of waitForFigureLayout.

waitForFigureLayout is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

yamada is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with yamada. If not, see <https://www.gnu.org/licenses/>.
%}

