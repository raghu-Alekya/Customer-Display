package com.creditcall.chipdnamobiledemo;

import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.Paint;
import android.graphics.Paint.Cap;
import android.graphics.Path;
import android.graphics.RectF;
import android.util.AttributeSet;
import android.view.MotionEvent;
import android.view.View;
import android.view.View.OnTouchListener;

import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

public class SignatureView extends View implements OnTouchListener {

    /**
     * Optimizes painting by invalidating the smallest possible area.
     */
    private Set<Path> gesture = new HashSet<>();
    private Path currentPath = new Path();
    private View enabler;
    private List<List<Point>> mDots;
    private Paint paint;

    public SignatureView(Context context, AttributeSet attrs) {
        super(context, attrs);
        float strokeWidth = getResources().getDisplayMetrics().density * 4;
        initSignatureView(strokeWidth);
    }

    private void initSignatureView(final float strokeWidth) {
        paint = new Paint();
        paint.setStrokeWidth(strokeWidth);
        paint.setAntiAlias(true);
        paint.setColor(getResources().getColor(android.R.color.tertiary_text_dark));
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeJoin(Paint.Join.ROUND);
        paint.setStrokeCap(Cap.ROUND);
        mDots = new ArrayList<List<Point>>();
        mDots.add(new ArrayList<Point>());
        setFocusable(true);
        setFocusableInTouchMode(true);
        this.setOnTouchListener(this);
    }

    /**
     * Erases the signature.
     */
    public void clear() {
        mDots = new ArrayList<List<Point>>();
        // To prevent an exception
        mDots.add(new ArrayList<Point>());
        currentPath = new Path();
        gesture = new HashSet<>();
        if (enabler != null) {
            enabler.setEnabled(false);
        }
        // Repaints the entire view.
        invalidate();
    }

    protected void onDraw(Canvas canvas) {
        for (Path path : gesture) {
            canvas.drawPath(path, paint);
        }
    }

    public boolean onTouch(final View view, final MotionEvent event) {
        handleEvent(event);
        return true;
    }

    void handleEvent(MotionEvent event) {
        if (event.getAction() != MotionEvent.ACTION_UP) {
            List<Point> points = mDots.get(mDots.size() - 1);
            final int size = event.getHistorySize();
            if (size > 0) {
                Point lastPoint = !points.isEmpty() ? (lastPoint = points.get(points.size() - 1)) : new Point();
                for (int i = 0; i < size; i++) {
                    Point point = new Point();
                    point.x = event.getHistoricalX(i);
                    point.y = event.getHistoricalY(i);
                    if (lastPoint.x != point.x || point.y != lastPoint.y) {
                        points.add(point);
                        lastPoint = point;
                    }
                }
                if (points.size() > 1) {
                    for (int i = points.size() - 2; i < points.size(); i++) {
                        if (i >= 0) {
                            Point point = points.get(i);

                            if (i == 0) {
                                Point next = points.get(i + 1);
                                point.dx = ((next.x - point.x) / 3);
                                point.dy = ((next.y - point.y) / 3);
                            } else if (i == points.size() - 1) {
                                Point prev = points.get(i - 1);
                                point.dx = ((point.x - prev.x) / 3);
                                point.dy = ((point.y - prev.y) / 3);
                            } else {
                                Point next = points.get(i + 1);
                                Point prev = points.get(i - 1);
                                point.dx = ((next.x - prev.x) / 3);
                                point.dy = ((next.y - prev.y) / 3);
                            }
                        }
                    }
                }
            } else {
                Point point = new Point();
                point.x = event.getX();
                point.y = event.getY();
                Point lastPoint;
                if (points.isEmpty() || ((lastPoint = points.get(points.size() - 1)).x != point.x || point.y != lastPoint.y)) {
                    points.add(point);
                }
            }
            currentPath.reset();
            boolean first = true;
            for (int i = 0; i < points.size(); i++) {
                Point point = points.get(i);
                if (first) {
                    first = false;
                    if (points.size() != 1) {
                        currentPath.moveTo(point.x, point.y);
                    } else {
                        currentPath.moveTo(point.x - 0.5f, point.y - 0.5f);
                        currentPath.lineTo(point.x + 0.5f, point.y + 0.5f);
                    }
                } else {
                    Point prev = points.get(i - 1);
                    currentPath.cubicTo(prev.x + prev.dx, prev.y + prev.dy, point.x - point.dx, point.y - point.dy, point.x, point.y);
                }
            }
            this.gesture.add(currentPath);
        } else {
            currentPath = new Path();
            mDots.add(new ArrayList<Point>());
            if (!enabler.isEnabled()) {
                enabler.setEnabled(true);
            }
        }
        invalidate();
    }


    public void setEnabler(View enabler) {
        this.enabler = enabler;
    }

    public Bitmap getBitmap() {
        Path path = new Path();
        for (Path p : gesture) {
            path.addPath(p);
        }
        gesture.clear();
        gesture.add(path);
        float strokeWidth = paint.getStrokeWidth();
        RectF bounds = new RectF();
        path.computeBounds(bounds, true);
        Bitmap b = null;
        if (!bounds.isEmpty()) {
            setDrawingCacheEnabled(true);
            int offset = (int) (2 * strokeWidth);
            int left = Math.max(0, (int) bounds.left - offset);
            int top = Math.max(0, (int) bounds.top - offset);
            int width = (int) Math.min(getWidth(), bounds.right + offset * 2) - left;
            int height = (int) Math.min(getHeight(), bounds.bottom + offset * 2) - top;
            float ratio = Math.min(0.5f, 2.f * Math.max(Math.max(250.f / width, 250.f / height), Math.max(25.f / width, 25.f / height)));
            if (ratio == 0) {
                ratio = 1;
            }
            paint.setStrokeWidth(strokeWidth / ratio);
            invalidate();
            b = Bitmap.createBitmap(getDrawingCache());
            b = Bitmap.createBitmap(b, left, top, width, height);
            b = Bitmap.createScaledBitmap(b, (int) (width * ratio), (int) (height * ratio), false);
            paint.setStrokeWidth(strokeWidth);
            invalidate();
            setDrawingCacheEnabled(false);
        }
        return b;
    }

    class Point {
        float x, y;
        float dx, dy;

        @Override
        public String toString() {
            return x + ", " + y;
        }
    }
}
