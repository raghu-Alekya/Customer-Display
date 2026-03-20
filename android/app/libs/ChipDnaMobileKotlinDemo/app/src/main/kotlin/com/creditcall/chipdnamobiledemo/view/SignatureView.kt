package com.creditcall.chipdnamobiledemo.view

import android.content.Context
import android.graphics.*
import android.graphics.Paint.Cap
import android.util.AttributeSet
import android.view.MotionEvent
import android.view.View
import android.view.View.OnTouchListener
import androidx.core.content.ContextCompat

class SignatureView(context: Context?, attrs: AttributeSet?) : View(context, attrs),
  OnTouchListener {

  /**
   * Optimizes painting by invalidating the smallest possible area.
   */
  private var gesture: MutableSet<Path> = HashSet()
  private var currentPath = Path()
  private var enabler: View? = null
  private lateinit var mDots: MutableList<MutableList<Point>>
  private lateinit var paint: Paint

  init {
    val strokeWidth = resources.displayMetrics.density * 4
    initSignatureView(strokeWidth)
  }

  override fun onDraw(canvas: Canvas) {
    for (path in gesture) {
      canvas.drawPath(path, paint)
    }
  }

  override fun onTouch(view: View, event: MotionEvent): Boolean {
    handleEvent(event)
    return true
  }

  fun clear() {
    mDots = mutableListOf(arrayListOf())
    // To prevent an exception
    currentPath = Path()
    gesture = HashSet()
    enabler?.isEnabled = false
    // Repaints the entire view.
    invalidate()
  }

  fun setEnabler(enabler: View) {
    this.enabler = enabler
  }

  fun getBitmap(): Bitmap? {
    val path = Path()
    for (p in gesture) {
      path.addPath(p)
    }
    gesture.clear()
    gesture.add(path)
    val strokeWidth = paint.strokeWidth
    val bounds = RectF()
    path.computeBounds(bounds, true)
    var b: Bitmap? = null
    if (!bounds.isEmpty) {
      isDrawingCacheEnabled = true
      val offset = (2 * strokeWidth).toInt()
      val left = 0.coerceAtLeast(bounds.left.toInt() - offset)
      val top = 0.coerceAtLeast(bounds.top.toInt() - offset)
      val width = width.toFloat().coerceAtMost(bounds.right + offset * 2).toInt() - left
      val height = height.toFloat().coerceAtMost(bounds.bottom + offset * 2).toInt() - top
      var ratio = 0.5f.coerceAtMost(
        2f * (250f / width).coerceAtLeast(250f / height)
          .coerceAtLeast((25f / width).coerceAtLeast(25f / height))
      )
      if (ratio == 0f) {
        ratio = 1f
      }
      paint.strokeWidth = strokeWidth / ratio
      invalidate()
      b = Bitmap.createBitmap(drawingCache)
      b = Bitmap.createBitmap(b, left, top, width, height)
      b = Bitmap.createScaledBitmap(
        b,
        (width * ratio).toInt(),
        (height * ratio).toInt(),
        false
      )
      paint.strokeWidth = strokeWidth
      invalidate()
      isDrawingCacheEnabled = false
    }
    return b
  }

  private fun handleEvent(event: MotionEvent) {
    if (event.action != MotionEvent.ACTION_UP) {
      val points = mDots[mDots.size - 1]
      val size = event.historySize
      if (size > 0) {
        var lastPoint = Point()
        if (points.isNotEmpty()) {
          lastPoint = points[points.lastIndex]
        }

        for (i in 0 until size) {
          val point = Point()
          point.x = event.getHistoricalX(i)
          point.y = event.getHistoricalY(i)
          if (lastPoint.x != point.x || point.y != lastPoint.y) {
            points.add(point)
            lastPoint = point
          }
        }
        if (points.size > 1) {
          for (i in points.size - 2 until points.size) {
            if (i >= 0) {
              val point = points[i]
              when (i) {
                0 -> {
                  val next = points[i + 1]
                  point.dx = (next.x - point.x) / 3
                  point.dy = (next.y - point.y) / 3
                }
                points.size - 1 -> {
                  val prev = points[i - 1]
                  point.dx = (point.x - prev.x) / 3
                  point.dy = (point.y - prev.y) / 3
                }
                else -> {
                  val next = points[i + 1]
                  val prev = points[i - 1]
                  point.dx = (next.x - prev.x) / 3
                  point.dy = (next.y - prev.y) / 3
                }
              }
            }
          }
        }
      } else {
        val point = Point()
        point.x = event.x
        point.y = event.y
        lateinit var lastPoint: Point
        if (points.isEmpty() || points[points.size - 1].also {
            lastPoint = it
          }.x != point.x || point.y != lastPoint.y) {
          points.add(point)
        }
      }
      currentPath.reset()
      var first = true
      for (i in points.indices) {
        val point = points[i]
        if (first) {
          first = false
          if (points.size != 1) {
            currentPath.moveTo(point.x, point.y)
          } else {
            currentPath.moveTo(point.x - 0.5f, point.y - 0.5f)
            currentPath.lineTo(point.x + 0.5f, point.y + 0.5f)
          }
        } else {
          val prev = points[i - 1]
          currentPath.cubicTo(
            prev.x + prev.dx,
            prev.y + prev.dy,
            point.x - point.dx,
            point.y - point.dy,
            point.x,
            point.y
          )
        }
      }
      gesture.add(currentPath)
    } else {
      currentPath = Path()
      mDots.add(ArrayList())
      enabler?.isEnabled = true
    }
    invalidate()
  }

  private fun initSignatureView(strokeWidth: Float) {
    paint = Paint()
    paint.strokeWidth = strokeWidth
    paint.isAntiAlias = true
    paint.color = ContextCompat.getColor(context, android.R.color.darker_gray)
    paint.style = Paint.Style.STROKE
    paint.strokeJoin = Paint.Join.ROUND
    paint.strokeCap = Cap.ROUND
    mDots = mutableListOf(arrayListOf())
    isFocusable = true
    isFocusableInTouchMode = true
    setOnTouchListener(this)
  }

  internal inner class Point {
    var x = 0f
    var y = 0f
    var dx = 0f
    var dy = 0f
    override fun toString(): String {
      return "$x, $y"
    }
  }

}