// ignore_for_file: avoid_print
import 'package:supabase_flutter/supabase_flutter.dart';

/// Centralized service for all Companion CRUD, booking, review, and escrow operations.
/// All times are stored/returned in UTC per spec Section 4.1.
class CompanionService {
  static final _sb = Supabase.instance.client;
  static String get _uid => _sb.auth.currentUser!.id;

  // ═══════════════════════════════════════════
  // SECTION 1: COMPANION PROFILE CRUD
  // ═══════════════════════════════════════════

  /// Fetch current user's companion profile (or null).
  static Future<Map<String, dynamic>?> getMyProfile() async {
    final res = await _sb.from('companion_profiles').select().eq('user_id', _uid).maybeSingle();
    return res;
  }

  /// Fetch a companion profile by ID.
  static Future<Map<String, dynamic>?> getProfile(String id) async {
    return await _sb.from('companion_profiles').select().eq('id', id).maybeSingle();
  }

  /// Fetch ACTIVE companions for discovery (Section 2).
  static Future<List<Map<String, dynamic>>> discoverCompanions({
    String? sessionType, // 'VIRTUAL' | 'PHYSICAL' | null=both
    String? language,
    String? tag,
    double? minRate,
    double? maxRate,
    double? minRating,
    bool? verifiedOnly,
    String sortBy = 'recommended', // recommended|newest|highest_rated|most_affordable|most_experienced
    int limit = 20,
    int offset = 0,
  }) async {
    // Build filter chain first (returns PostgrestFilterBuilder)
    var filterQ = _sb.from('companion_profiles').select().eq('status', 'ACTIVE');
    if (sessionType == 'VIRTUAL') filterQ = filterQ.eq('is_virtual_enabled', true);
    if (sessionType == 'PHYSICAL') filterQ = filterQ.eq('is_physical_enabled', true);
    if (verifiedOnly == true) filterQ = filterQ.eq('is_id_verified', true);
    if (minRating != null) filterQ = filterQ.gte('overall_rating', minRating);

    // Apply sort (order returns PostgrestTransformBuilder, use dynamic)
    String sortCol;
    bool sortAsc;
    switch (sortBy) {
      case 'newest':
        sortCol = 'created_at'; sortAsc = false;
        break;
      case 'highest_rated':
        sortCol = 'overall_rating'; sortAsc = false;
        break;
      case 'most_affordable':
        sortCol = 'virtual_rate_per_hour'; sortAsc = true;
        break;
      case 'most_experienced':
        sortCol = 'total_sessions'; sortAsc = false;
        break;
      default:
        sortCol = 'overall_rating'; sortAsc = false;
    }

    final data = await filterQ
        .order(sortCol, ascending: sortAsc)
        .range(offset, offset + limit - 1);
    List<Map<String, dynamic>> results = List<Map<String, dynamic>>.from(data);

    // Client-side filters for language, tag, rate range
    if (language != null) {
      results = results.where((c) {
        final langs = (c['languages'] as List?) ?? [];
        return langs.contains(language);
      }).toList();
    }
    if (tag != null) {
      results = results.where((c) {
        final tags = (c['tags'] as List?) ?? [];
        return tags.contains(tag);
      }).toList();
    }
    if (minRate != null) {
      results = results.where((c) {
        final vr = (c['virtual_rate_per_hour'] ?? 0).toDouble();
        final pr = (c['physical_rate_per_hour'] ?? 0).toDouble();
        return vr >= minRate || pr >= minRate;
      }).toList();
    }
    if (maxRate != null) {
      results = results.where((c) {
        final vr = (c['virtual_rate_per_hour'] ?? 99999).toDouble();
        final pr = (c['physical_rate_per_hour'] ?? 99999).toDouble();
        return vr <= maxRate || pr <= maxRate;
      }).toList();
    }

    return results;
  }

  // ═══════════════════════════════════════════
  // SECTION 2: AVAILABILITY
  // ═══════════════════════════════════════════

  static Future<List<Map<String, dynamic>>> getAvailability(String companionId) async {
    final data = await _sb.from('companion_availability').select().eq('companion_id', companionId).eq('is_active', true);
    return List<Map<String, dynamic>>.from(data);
  }

  static Future<List<Map<String, dynamic>>> getBlackoutDates(String companionId) async {
    final data = await _sb.from('companion_blackout_dates').select().eq('companion_id', companionId);
    return List<Map<String, dynamic>>.from(data);
  }

  // ═══════════════════════════════════════════
  // SECTION 3: BOOKING FLOW
  // ═══════════════════════════════════════════

  /// EC-01: Check if companion has a confirmed booking overlapping the requested time.
  static Future<bool> isSlotAvailable(String companionId, DateTime startUtc, int durationMinutes) async {
    final endUtc = startUtc.add(Duration(minutes: durationMinutes));
    final conflicts = await _sb
        .from('companion_bookings')
        .select('id')
        .eq('companion_id', companionId)
        .inFilter('status', ['PENDING_CONFIRMATION', 'CONFIRMED', 'ACTIVE'])
        .lt('scheduled_start_utc', endUtc.toIso8601String())
        .gt('scheduled_end_utc', startUtc.toIso8601String());
    return (conflicts as List).isEmpty;
  }

  /// EC-04: Check if this booker-companion pair is blocked due to past dispute.
  static Future<bool> isPairBlocked(String companionId) async {
    final disputes = await _sb
        .from('companion_dispute_pairs')
        .select('id')
        .or('booker_id.eq.$_uid,companion_id.eq.$companionId')
        .eq('is_blocked', true);
    return (disputes as List).isNotEmpty;
  }

  /// Create a booking (Section 3.1 Steps 1-4). Returns booking ID or throws.
  /// EC-05: Rate locked at booking time.
  static Future<String> createBooking({
    required String companionId,
    required String sessionType, // 'VIRTUAL' or 'PHYSICAL'
    required DateTime scheduledStartUtc,
    required int durationMinutes,
    required double ratePerHour,
    String? bookerNote,
    String? meetLocation, // physical only
    String? idempotencyKey, // EC-18
  }) async {
    // EC-01: Slot check
    final available = await isSlotAvailable(companionId, scheduledStartUtc, durationMinutes);
    if (!available) throw Exception('Time slot is no longer available');

    // EC-04: Dispute pair check
    final blocked = await isPairBlocked(companionId);
    if (blocked) throw Exception('This booking is unavailable');

    // Self-booking prevention (Section 14)
    final companionProfile = await getProfile(companionId);
    if (companionProfile?['user_id'] == _uid) throw Exception('Cannot book yourself');

    final sessionCost = (durationMinutes / 60.0) * ratePerHour;
    final platformFee = sessionCost * 0.15; // 15% platform fee
    final totalCharged = sessionCost + platformFee;
    final endUtc = scheduledStartUtc.add(Duration(minutes: durationMinutes));

    final data = await _sb.from('companion_bookings').insert({
      'booker_id': _uid,
      'companion_id': companionId,
      'session_type': sessionType,
      'status': 'PENDING_CONFIRMATION',
      'scheduled_start_utc': scheduledStartUtc.toUtc().toIso8601String(),
      'scheduled_end_utc': endUtc.toUtc().toIso8601String(),
      'duration_minutes': durationMinutes,
      'rate_per_hour': ratePerHour,
      'session_cost': sessionCost,
      'platform_fee': platformFee,
      'total_charged': totalCharged,
      'booker_note': bookerNote,
      'meet_location': meetLocation,
      'escrow_status': 'HELD',
      'idempotency_key': idempotencyKey,
    }).select('id').single();

    final bookingId = data['id'] as String;

    // Create escrow transaction (Section 6.1)
    await _sb.from('companion_escrow_transactions').insert({
      'booking_id': bookingId,
      'amount': totalCharged,
      'currency': 'INR',
      'status': 'HELD',
      'held_at': DateTime.now().toUtc().toIso8601String(),
      'companion_payout_amount': sessionCost * 0.85,
      'platform_revenue': platformFee,
    });

    // Schedule notification jobs (Section 4.2) — N-01, N-02
    await _scheduleBookingNotifications(bookingId, companionId, scheduledStartUtc, durationMinutes);

    return bookingId;
  }

  /// Companion accepts/declines/proposes alternative (Section 3.1 Step 6).
  static Future<void> respondToBooking(String bookingId, String action, {DateTime? alternativeTime}) async {
    switch (action) {
      case 'ACCEPT':
        await _sb.from('companion_bookings').update({'status': 'CONFIRMED'}).eq('id', bookingId);
        // Create video room if virtual (Section 5.1)
        final booking = await _sb.from('companion_bookings').select().eq('id', bookingId).single();
        if (booking['session_type'] == 'VIRTUAL') {
          await _createVideoRoom(bookingId);
        }
        // Schedule session notifications (T-24h, T-1h, T-10m, etc.)
        await _scheduleSessionNotifications(bookingId, DateTime.parse(booking['scheduled_start_utc']), booking['duration_minutes'] as int);
        break;
      case 'DECLINE':
        await _sb.from('companion_bookings').update({'status': 'CANCELLED_BY_COMPANION'}).eq('id', bookingId);
        // Refund escrow
        await _sb.from('companion_escrow_transactions').update({'status': 'REFUNDED', 'released_at': DateTime.now().toUtc().toIso8601String(), 'release_type': 'AUTO'}).eq('booking_id', bookingId);
        break;
      case 'PROPOSE_ALTERNATIVE':
        if (alternativeTime != null) {
          await _sb.from('companion_bookings').update({'status': 'RESCHEDULED', 'scheduled_start_utc': alternativeTime.toUtc().toIso8601String()}).eq('id', bookingId);
        }
        break;
    }
  }

  /// Cancel booking by booker (Section 8.1 refund matrix).
  static Future<double> cancelByBooker(String bookingId) async {
    final booking = await _sb.from('companion_bookings').select().eq('id', bookingId).single();
    final startUtc = DateTime.parse(booking['scheduled_start_utc']);
    final hoursUntil = startUtc.difference(DateTime.now().toUtc()).inHours;
    final totalCharged = (booking['total_charged'] as num).toDouble();

    double refundPercent;
    if (hoursUntil > 48) {
      refundPercent = 1.0;
    } else if (hoursUntil > 24) {
      refundPercent = 0.75;
    } else if (hoursUntil > 12) {
      refundPercent = 0.50;
    } else if (hoursUntil > 0) {
      refundPercent = 0.25;
    } else {
      refundPercent = 0.0; // counts as no-show
    }

    final refundAmount = totalCharged * refundPercent;
    await _sb.from('companion_bookings').update({'status': 'CANCELLED_BY_BOOKER'}).eq('id', bookingId);
    await _sb.from('companion_escrow_transactions').update({
      'status': refundPercent == 1.0 ? 'REFUNDED' : 'PARTIAL_REFUND',
      'booker_refund_amount': refundAmount,
      'released_at': DateTime.now().toUtc().toIso8601String(),
      'release_type': 'AUTO',
    }).eq('booking_id', bookingId);

    // Cancel pending notification jobs (EC-26)
    await _sb
        .from('companion_notification_jobs')
        .update({'status': 'CANCELLED'})
        .eq('booking_id', bookingId)
        .eq('status', 'PENDING');

    return refundAmount;
  }

  // ═══════════════════════════════════════════
  // SECTION 5: VIDEO ROOM
  // ═══════════════════════════════════════════

  static Future<void> _createVideoRoom(String bookingId) async {
    final bookerToken = _generateToken();
    final companionToken = _generateToken();
    await _sb.from('companion_video_rooms').insert({
      'booking_id': bookingId,
      'status': 'CREATED',
      'booker_join_token': bookerToken,
      'companion_join_token': companionToken,
    });
  }

  static String _generateToken() {
    final now = DateTime.now().microsecondsSinceEpoch;
    return 'ctkn_${now}_${now.hashCode.toRadixString(36)}';
  }

  /// Get video room for a booking.
  static Future<Map<String, dynamic>?> getVideoRoom(String bookingId) async {
    return await _sb.from('companion_video_rooms').select().eq('booking_id', bookingId).maybeSingle();
  }

  // ═══════════════════════════════════════════
  // SECTION 9: REVIEWS
  // ═══════════════════════════════════════════

  static Future<void> submitReview({
    required String bookingId,
    required String revieweeId,
    required String reviewerRole, // 'BOOKER' or 'COMPANION'
    required int overallRating,
    String? wasPunctual,
    String? wouldBookAgain,
    String? writtenReview,
    String? privateFeedback,
  }) async {
    await _sb.from('companion_session_reviews').insert({
      'booking_id': bookingId,
      'reviewer_id': _uid,
      'reviewee_id': revieweeId,
      'reviewer_role': reviewerRole,
      'overall_rating': overallRating,
      'was_punctual': wasPunctual,
      'would_book_again': wouldBookAgain,
      'written_review': writtenReview,
      'private_feedback': privateFeedback,
      'is_published': true,
    });
  }

  static Future<List<Map<String, dynamic>>> getReviews(String companionId) async {
    // Get all bookings for this companion, then reviews
    final data = await _sb.from('companion_session_reviews')
        .select('*, companion_bookings!inner(companion_id)')
        .eq('is_published', true)
        .order('created_at', ascending: false)
        .limit(50);
    return List<Map<String, dynamic>>.from(data);
  }

  // ═══════════════════════════════════════════
  // SECTION 7: SAFETY
  // ═══════════════════════════════════════════

  static Future<void> fileSafetyReport({
    required String bookingId,
    required String reportedUserId,
    required String reportType, // IN_SESSION_REPORT, SOS, POST_SESSION
    required String reason,
    String? details,
  }) async {
    await _sb.from('companion_safety_reports').insert({
      'session_id': bookingId,
      'reporter_id': _uid,
      'reported_user_id': reportedUserId,
      'report_type': reportType,
      'reason': reason,
      'details': details,
      'status': reportType == 'SOS' ? 'UNDER_REVIEW' : 'PENDING',
    });
  }

  // ═══════════════════════════════════════════
  // SECTION 12: NOTIFICATION SCHEDULING
  // ═══════════════════════════════════════════

  static Future<void> _scheduleBookingNotifications(String bookingId, String companionId, DateTime startUtc, int durationMinutes) async {
    final companionProfile = await getProfile(companionId);
    final companionUserId = companionProfile?['user_id'] as String?;
    if (companionUserId == null) return;

    // N-01: Notify companion of booking request
    await _insertNotificationJob(bookingId, 'N-01', DateTime.now().toUtc(), companionUserId);
    // N-02: Confirm to booker
    await _insertNotificationJob(bookingId, 'N-02', DateTime.now().toUtc(), _uid);
  }

  static Future<void> _scheduleSessionNotifications(String bookingId, DateTime startUtc, int durationMinutes) async {
    final booking = await _sb.from('companion_bookings').select().eq('id', bookingId).single();
    final bookerId = booking['booker_id'] as String;
    final companionProfile = await getProfile(booking['companion_id']);
    final companionUserId = companionProfile?['user_id'] as String? ?? '';
    final endUtc = startUtc.add(Duration(minutes: durationMinutes));

    // N-06: T-24h
    await _insertNotificationJob(bookingId, 'N-06', startUtc.subtract(const Duration(hours: 24)), bookerId);
    await _insertNotificationJob(bookingId, 'N-06', startUtc.subtract(const Duration(hours: 24)), companionUserId);
    // N-07: T-1h
    await _insertNotificationJob(bookingId, 'N-07', startUtc.subtract(const Duration(hours: 1)), bookerId);
    await _insertNotificationJob(bookingId, 'N-07', startUtc.subtract(const Duration(hours: 1)), companionUserId);
    // N-08: T-10m (PRIMARY)
    await _insertNotificationJob(bookingId, 'N-08', startUtc.subtract(const Duration(minutes: 10)), bookerId);
    await _insertNotificationJob(bookingId, 'N-08', startUtc.subtract(const Duration(minutes: 10)), companionUserId);
    // N-09: T+0
    await _insertNotificationJob(bookingId, 'N-09', startUtc, bookerId);
    await _insertNotificationJob(bookingId, 'N-09', startUtc, companionUserId);
    // N-17: T+1h after end (review request)
    await _insertNotificationJob(bookingId, 'N-17', endUtc.add(const Duration(hours: 1)), bookerId);
    await _insertNotificationJob(bookingId, 'N-17', endUtc.add(const Duration(hours: 1)), companionUserId);
  }

  static Future<void> _insertNotificationJob(String bookingId, String type, DateTime scheduledUtc, String recipientId) async {
    await _sb.from('companion_notification_jobs').insert({
      'booking_id': bookingId,
      'notification_type': type,
      'scheduled_for_utc': scheduledUtc.toUtc().toIso8601String(),
      'recipient_user_id': recipientId,
      'status': 'PENDING',
      'retry_count': 0,
    });
  }

  // ═══════════════════════════════════════════
  // BOOKINGS LIST
  // ═══════════════════════════════════════════

  /// Get bookings where current user is the booker.
  static Future<List<Map<String, dynamic>>> getMyBookingsAsBooker() async {
    final data = await _sb.from('companion_bookings').select('*, companion_profiles(*)').eq('booker_id', _uid).order('scheduled_start_utc', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  /// Get bookings where current user is the companion.
  static Future<List<Map<String, dynamic>>> getMyBookingsAsCompanion() async {
    final myProfile = await getMyProfile();
    if (myProfile == null) return [];
    final data = await _sb.from('companion_bookings').select().eq('companion_id', myProfile['id']).order('scheduled_start_utc', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }
}
