// Copyright (C) 2026 Nobuto Kaitoh
// SPDX-License-Identifier: GPL-3.0-or-later
// This file is part of yamada. See LICENSE for the license text.

(config => {
    const delay = milliseconds => new Promise(resolve => setTimeout(resolve, milliseconds));
    require(["viewmodel/impl/ViewModelManagerFactory", "MW/componentframework/ControllerService"],
        async (factory, service) => {
            const managers = Object.values(factory._viewModelManagerCache)
                .filter(manager => manager.hasById(config.figureId));
            if (managers.length !== 1) {
                throw new Error("Expected one ViewModel manager for this figure.");
            }
            const manager = managers[0];
            const viewModel = manager.getById(config.figureId);
            const send = result => viewModel.dispatchEvent(config.eventName, viewModel,
                result);

            try {
                // Keep resize timestamps across calls in this demo figure.
                const resize = viewModel.figureLayoutWaitResize ??= {
                    last: performance.now(), hooked: new WeakSet()
                };
                const cache = service.getInstance(config.channel)._controllerCache;
                const controllers = cache instanceof Map ? [...cache.values()] : Object.values(cache);
                let watched = 0;
                for (const controller of controllers) {
                    const original = controller?.emitContainerResizeControllerEvent;
                    if (typeof original !== "function") continue;
                    watched++;
                    if (resize.hooked.has(controller)) continue;

                    controller.emitContainerResizeControllerEvent = function (...args) {
                        resize.last = performance.now();
                        return original.apply(this, args);
                    };
                    resize.hooked.add(controller);
                    resize.last = performance.now();
                }
                if (watched === 0) throw new Error("No resize emitters found.");

                // Let pending browser work run, then wait out the trailing resize timer.
                document.body.getBoundingClientRect();
                await delay(0);
                const started = performance.now();
                while (performance.now() - resize.last < 220) {
                    if (performance.now() - started >= 3000) {
                        throw new Error("Resize activity did not settle within 3 seconds.");
                    }
                    await delay(10);
                }

                // Drain registered layout work where supported, then wait one frame.
                const root = manager.getRoot();
                if (typeof root.stabilize === "function") await root.stabilize();
                await new Promise(resolve => requestAnimationFrame(resolve));
                send({ completed: true });
            } catch (error) {
                send({ error: String(error) });
            }
        });
    return config.eventName;
})(__LAYOUT_WAIT_CONFIGURATION__)