import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../utils/haptics.dart';
import 'element_registry.dart';
import 'simulation_engine.dart';
import 'pixel_renderer.dart';

// ---------------------------------------------------------------------------
// SandboxInputHandler — Input handling, drawing, undo for the sandbox
// ---------------------------------------------------------------------------

/// Snapshot for undo history.
class UndoSnapshot {
  final Uint8List grid;
  final Uint8List life;
  final Int8List velX;
  final Int8List velY;
  const UndoSnapshot({
    required this.grid,
    required this.life,
    required this.velX,
    required this.velY,
  });
}

/// Handles all touch/gesture input, element placement, line drawing, and undo.
class SandboxInputHandler {
  final SimulationEngine engine;
  final PixelRenderer renderer;

  // -- Drawing state -------------------------------------------------------
  int selectedElement = El.sand;
  int brushSize = 1;    // 1, 3, or 5
  int brushMode = 0;    // 0=circle, 1=line, 2=spray
  int selectedSeedType = 1; // 1-5 seed sub-types
  int lineStartX = -1;
  int lineStartY = -1;
  int lineEndX = -1;
  int lineEndY = -1;
  bool isDrawing = false;

  // -- Canvas layout (updated by widget each frame) ----------------------
  double canvasTop = 0;
  double canvasLeft = 0;
  double cellSize = 1.0;

  // -- Undo history -------------------------------------------------------
  final List<UndoSnapshot> undoHistory = [];
  static const int maxUndoHistory = 10;
  bool _isCapturingStroke = false;

  // -- Callbacks ----------------------------------------------------------
  /// Called when the handler needs to trigger a setState.
  VoidCallback? onStateChanged;

  SandboxInputHandler(this.engine, this.renderer);

  void captureUndoSnapshot() {
    if (!_isCapturingStroke) {
      _isCapturingStroke = true;
      undoHistory.add(UndoSnapshot(
        grid: Uint8List.fromList(engine.grid),
        life: Uint8List.fromList(engine.life),
        velX: Int8List.fromList(engine.velX),
        velY: Int8List.fromList(engine.velY),
      ));
      if (undoHistory.length > maxUndoHistory) {
        undoHistory.removeAt(0);
      }
    }
  }

  void undo() {
    if (undoHistory.isEmpty) return;
    final snapshot = undoHistory.removeLast();
    engine.grid.setAll(0, snapshot.grid);
    engine.life.setAll(0, snapshot.life);
    engine.velX.setAll(0, snapshot.velX);
    engine.velY.setAll(0, snapshot.velY);
    engine.pheroFood.fillRange(0, engine.pheroFood.length, 0);
    engine.pheroHome.fillRange(0, engine.pheroHome.length, 0);
    engine.colonyX = -1;
    engine.colonyY = -1;
    renderer.clearParticles();
    engine.markAllDirty();
    Haptics.tap();
  }

  void handlePanStart(DragStartDetails details, bool sessionExpired) {
    if (sessionExpired) return;
    captureUndoSnapshot();
    isDrawing = true;
    if (brushMode == 1) {
      lineStartX = ((details.localPosition.dx - canvasLeft) / cellSize).floor();
      lineStartY = ((details.localPosition.dy - canvasTop) / cellSize).floor();
      lineEndX = lineStartX;
      lineEndY = lineStartY;
    } else {
      placeElement(details.localPosition);
    }
  }

  void handlePanUpdate(DragUpdateDetails details, bool sessionExpired) {
    if (sessionExpired) return;
    if (isDrawing) {
      if (brushMode == 1) {
        lineEndX = ((details.localPosition.dx - canvasLeft) / cellSize).floor();
        lineEndY = ((details.localPosition.dy - canvasTop) / cellSize).floor();
      } else {
        placeElement(details.localPosition);
      }
    }
  }

  void handlePanEnd(DragEndDetails details) {
    if (brushMode == 1 && lineStartX >= 0) {
      drawLine(lineStartX, lineStartY, lineEndX, lineEndY);
    }
    isDrawing = false;
    _isCapturingStroke = false;
    lineStartX = -1;
    lineStartY = -1;
  }

  void handleTapDown(TapDownDetails details, bool sessionExpired) {
    if (sessionExpired) return;
    captureUndoSnapshot();
    placeElement(details.localPosition);
    _isCapturingStroke = false;
    Haptics.tap();
  }

  void handleLongPressStart(LongPressStartDetails details, bool sessionExpired) {
    if (sessionExpired) return;
    captureUndoSnapshot();
    isDrawing = true;
    placeElement(details.localPosition, burst: true);
  }

  void handleLongPressMoveUpdate(LongPressMoveUpdateDetails details, bool sessionExpired) {
    if (sessionExpired) return;
    if (isDrawing) {
      placeElement(details.localPosition, burst: true);
    }
  }

  void handleLongPressEnd(LongPressEndDetails details) {
    isDrawing = false;
    _isCapturingStroke = false;
  }

  void placeElement(Offset pos, {bool burst = false}) {
    final gx = ((pos.dx - canvasLeft) / cellSize).floor();
    final gy = ((pos.dy - canvasTop) / cellSize).floor();

    // Seeds always place a single cell (no brush size scaling)
    if (selectedElement == El.seed) {
      _placeAtCell(gx, gy);
      return;
    }

    final radius = burst ? brushSize + 2 : brushSize;
    final halfR = radius ~/ 2;

    for (int dy = -halfR; dy <= halfR; dy++) {
      for (int dx = -halfR; dx <= halfR; dx++) {
        if (radius > 1 && dx * dx + dy * dy > halfR * halfR + 1) continue;

        // Spray mode: 40% chance per cell
        if (brushMode == 2 && engine.rng.nextInt(100) >= 40) continue;

        _placeAtCell(gx + dx, gy + dy);
      }
    }
  }

  /// Bresenham line drawing from (x0,y0) to (x1,y1).
  void drawLine(int x0, int y0, int x1, int y1) {
    int dx = (x1 - x0).abs();
    int dy = -(y1 - y0).abs();
    int sx = x0 < x1 ? 1 : -1;
    int sy = y0 < y1 ? 1 : -1;
    int err = dx + dy;

    int cx = x0;
    int cy = y0;

    while (true) {
      placeAt(cx, cy);
      if (cx == x1 && cy == y1) break;
      final e2 = 2 * err;
      if (e2 >= dy) {
        err += dy;
        cx += sx;
      }
      if (e2 <= dx) {
        err += dx;
        cy += sy;
      }
    }
  }

  /// Place element at a single grid cell (for line drawing).
  void placeAt(int gx, int gy) {
    // Seeds always place a single cell
    if (selectedElement == El.seed) {
      _placeAtCell(gx, gy);
      return;
    }

    final halfR = brushSize ~/ 2;
    for (int dy = -halfR; dy <= halfR; dy++) {
      for (int dx = -halfR; dx <= halfR; dx++) {
        if (brushSize > 1 && dx * dx + dy * dy > halfR * halfR + 1) continue;
        _placeAtCell(gx + dx, gy + dy);
      }
    }
  }

  /// Core single-cell placement logic shared by [placeElement] and [placeAt].
  void _placeAtCell(int gx, int gy) {
    if (!engine.inBounds(gx, gy)) return;
    final ni = gy * engine.gridW + gx;

    if (selectedElement == El.seed) {
      if (engine.grid[ni] != El.empty) return;
      engine.grid[ni] = El.seed;
      engine.life[ni] = 0;
      engine.velX[ni] = selectedSeedType;
      engine.velY[ni] = 0;
      engine.markDirty(gx, gy);
      return;
    }

    if (selectedElement == El.eraser) {
      engine.grid[ni] = El.empty;
      engine.life[ni] = 0;
      engine.velX[ni] = 0;
      engine.velY[ni] = 0;
      engine.markDirty(gx, gy);
      return;
    }

    if (engine.grid[ni] != El.empty && selectedElement != El.lightning) return;

    engine.grid[ni] = selectedElement;
    engine.life[ni] = selectedElement == El.water ? 100 : 0;
    engine.velY[ni] = 0;
    engine.markDirty(gx, gy);
  }

  void clearGrid() {
    captureUndoSnapshot();
    _isCapturingStroke = false;
    engine.clear();
    renderer.clearParticles();
    Haptics.tap();
  }
}
