import React, { useEffect, useState } from 'react';
import api from '../services/api';
import { Users, Clock, TrendingUp, Calendar, ChevronRight, XCircle, Activity } from 'lucide-react';

type ActivityStat = {
  date: string;
  sessionCount: number;
  totalDurationSeconds: number;
  totalDurationMinutes: number;
  totalDurationHours: number;
  userId: number;
  userName: string;
};

type UserActivity = {
  id: number;
  sessionStart: string;
  sessionEnd?: string;
  durationSeconds?: number;
  deviceInfo?: string;
  ipAddress?: string;
  appVersion?: string;
  user: {
    id: number;
    name: string;
  };
};

const UserActivityDashboard: React.FC = () => {
  const [stats, setStats] = useState<ActivityStat[]>([]);
  const [selectedDate, setSelectedDate] = useState<string | null>(null);
  const [selectedDateActivities, setSelectedDateActivities] = useState<UserActivity[]>([]);
  const [loading, setLoading] = useState(false);
  const [showModal, setShowModal] = useState(false);

  const loadStats = async () => {
    setLoading(true);
    try {
      const res = await api.get('user-activities/daily-stats');
      setStats(res.data || []);
    } catch (e) {
      console.error('Failed to load stats:', e);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadStats();
  }, []);

  const openDateDetails = async (date: string) => {
    setSelectedDate(date);
    setLoading(true);
    try {
      const res = await api.get(`user-activities/date/${date}`);
      setSelectedDateActivities(res.data || []);
      setShowModal(true);
    } catch (e) {
      console.error('Failed to load activities:', e);
    } finally {
      setLoading(false);
    }
  };

  const formatDuration = (seconds: number) => {
    const hours = Math.floor(seconds / 3600);
    const minutes = Math.floor((seconds % 3600) / 60);
    const secs = seconds % 60;
    if (hours > 0) {
      return `${hours}h ${minutes}m`;
    } else if (minutes > 0) {
      return `${minutes}m ${secs}s`;
    } else {
      return `${secs}s`;
    }
  };

  const formatDateTime = (isoString: string) => {
    const date = new Date(isoString);
    return date.toLocaleString('en-IN', {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit'
    });
  };

  // Group stats by date
  const statsByDate: { [key: string]: ActivityStat[] } = {};
  stats.forEach(stat => {
    if (!statsByDate[stat.date]) {
      statsByDate[stat.date] = [];
    }
    statsByDate[stat.date].push(stat);
  });

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900 flex items-center gap-2">
            <Activity size={28} className="text-primary-600" />
            User Activity Monitoring
          </h1>
          <p className="text-gray-500 font-medium mt-1">Track user app usage, sessions, and engagement</p>
        </div>
        <button 
          onClick={loadStats}
          className="flex items-center gap-2 px-4 py-2 bg-primary-600 text-white rounded-xl font-bold hover:bg-primary-700 transition-all"
        >
          <TrendingUp size={18} />
          Refresh
        </button>
      </div>

      {loading && stats.length === 0 ? (
        <div className="flex justify-center py-20">
          <div className="w-10 h-10 border-4 border-primary-200 border-t-primary-600 rounded-full animate-spin"></div>
        </div>
      ) : (
        <div className="space-y-6">
          {Object.keys(statsByDate).length === 0 ? (
            <div className="text-center py-20 bg-white rounded-3xl border border-gray-100">
              <Calendar size={64} className="mx-auto text-gray-300 mb-4" />
              <h3 className="text-lg font-bold text-gray-700 mb-2">No activity data yet</h3>
              <p className="text-gray-500 font-medium">User activity will appear here once users start using the app</p>
            </div>
          ) : (
            Object.keys(statsByDate).sort((a, b) => b.localeCompare(a)).map(date => {
              const dateStats = statsByDate[date];
              const totalSessions = dateStats.reduce((sum, s) => sum + s.sessionCount, 0);
              const totalDurationSeconds = dateStats.reduce((sum, s) => sum + s.totalDurationSeconds, 0);

              return (
                <div 
                  key={date} 
                  className="bg-white rounded-3xl border border-gray-100 shadow-sm p-8 hover:shadow-lg transition-all cursor-pointer"
                  onClick={() => openDateDetails(date)}
                >
                  <div className="flex items-center justify-between mb-6">
                    <div className="flex items-center gap-3">
                      <div className="w-12 h-12 bg-primary-50 rounded-2xl flex items-center justify-center">
                        <Calendar size={24} className="text-primary-600" />
                      </div>
                      <div>
                        <h3 className="text-xl font-black text-gray-900">
                          {new Date(date).toLocaleDateString('en-IN', {
                            weekday: 'long',
                            year: 'numeric',
                            month: 'long',
                            day: 'numeric'
                          })}
                        </h3>
                        <p className="text-gray-500 font-medium">
                          {totalSessions} sessions • Total time: {formatDuration(totalDurationSeconds)}
                        </p>
                      </div>
                    </div>
                    <div className="flex items-center gap-2 text-primary-600 font-bold">
                      View Details
                      <ChevronRight size={20} />
                    </div>
                  </div>

                  <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                    {dateStats.map(stat => (
                      <div 
                        key={stat.userId} 
                        className="p-6 bg-gray-50 rounded-2xl border border-gray-100 hover:border-gray-200 transition-all"
                      >
                        <div className="flex items-center gap-3 mb-4">
                          <div className="w-10 h-10 bg-indigo-50 rounded-full flex items-center justify-center">
                            <Users size={20} className="text-indigo-600" />
                          </div>
                          <div>
                            <div className="font-bold text-gray-900">{stat.userName}</div>
                            <div className="text-xs text-gray-500 font-medium uppercase tracking-wider">
                              {stat.sessionCount} {stat.sessionCount === 1 ? 'session' : 'sessions'}
                            </div>
                          </div>
                        </div>
                        
                        <div className="flex items-center gap-3 text-sm">
                          <div className="flex items-center gap-2 text-gray-600">
                            <Clock size={16} />
                            <span className="font-bold">{formatDuration(stat.totalDurationSeconds)}</span>
                          </div>
                        </div>
                      </div>
                    ))}
                  </div>
                </div>
              );
            })
          )}
        </div>
      )}

      {/* Modal for date details */}
      {showModal && selectedDate && (
        <div className="fixed inset-0 bg-black/60 backdrop-blur-sm flex items-center justify-center p-4 z-[100]">
          <div className="bg-white rounded-[2.5rem] max-w-4xl w-full max-h-[85vh] overflow-hidden shadow-2xl border border-gray-100 animate-in fade-in zoom-in duration-200">
            <div className="p-8 border-b border-gray-100 flex items-center justify-between">
              <div>
                <h3 className="text-2xl font-black text-gray-900">
                  Activity Details - {new Date(selectedDate).toLocaleDateString('en-IN', {
                    weekday: 'long',
                    year: 'numeric',
                    month: 'long',
                    day: 'numeric'
                  })}
                </h3>
                <p className="text-gray-500 font-medium mt-1">
                  {selectedDateActivities.length} total sessions
                </p>
              </div>
              <button 
                onClick={() => setShowModal(false)} 
                className="p-2 hover:bg-gray-100 rounded-full transition-colors"
              >
                <XCircle size={24} className="text-gray-400" />
              </button>
            </div>

            <div className="p-8 overflow-y-auto max-h-[calc(85vh-140px)]">
              {loading ? (
                <div className="flex justify-center py-10">
                  <div className="w-8 h-8 border-4 border-primary-200 border-t-primary-600 rounded-full animate-spin"></div>
                </div>
              ) : selectedDateActivities.length === 0 ? (
                <div className="text-center py-10 text-gray-500 font-medium">No activities found for this date</div>
              ) : (
                <div className="space-y-4">
                  {selectedDateActivities.map(activity => (
                    <div 
                      key={activity.id} 
                      className="p-6 bg-gray-50 rounded-2xl border border-gray-100"
                    >
                      <div className="flex items-center justify-between mb-4">
                        <div className="flex items-center gap-4">
                          <div className="w-12 h-12 bg-indigo-50 rounded-2xl flex items-center justify-center">
                            <Users size={24} className="text-indigo-600" />
                          </div>
                          <div>
                            <div className="font-black text-gray-900">{activity.user.name}</div>
                            <div className="text-sm text-gray-500">
                              {formatDateTime(activity.sessionStart)}
                            </div>
                          </div>
                        </div>
                        {activity.durationSeconds !== undefined && (
                          <div className="bg-green-50 text-green-700 px-4 py-2 rounded-xl font-bold">
                            {formatDuration(activity.durationSeconds)}
                          </div>
                        )}
                      </div>

                      <div className="grid grid-cols-1 md:grid-cols-3 gap-4 text-sm">
                        {activity.deviceInfo && (
                          <div className="p-3 bg-white rounded-xl border border-gray-100">
                            <span className="text-xs font-bold text-gray-500 uppercase tracking-wider block mb-1">Device</span>
                            <span className="font-medium text-gray-800">{activity.deviceInfo}</span>
                          </div>
                        )}
                        {activity.ipAddress && (
                          <div className="p-3 bg-white rounded-xl border border-gray-100">
                            <span className="text-xs font-bold text-gray-500 uppercase tracking-wider block mb-1">IP Address</span>
                            <span className="font-medium text-gray-800">{activity.ipAddress}</span>
                          </div>
                        )}
                        {activity.appVersion && (
                          <div className="p-3 bg-white rounded-xl border border-gray-100">
                            <span className="text-xs font-bold text-gray-500 uppercase tracking-wider block mb-1">App Version</span>
                            <span className="font-medium text-gray-800">{activity.appVersion}</span>
                          </div>
                        )}
                      </div>

                      {activity.sessionEnd && (
                        <div className="mt-4 text-xs text-gray-400 font-medium">
                          Session ended at: {formatDateTime(activity.sessionEnd)}
                        </div>
                      )}
                    </div>
                  ))}
                </div>
              )}
            </div>

            <div className="p-8 border-t border-gray-100 bg-gray-50">
              <button 
                onClick={() => setShowModal(false)}
                className="w-full px-6 py-4 bg-gray-200 text-gray-700 rounded-2xl font-black hover:bg-gray-300 transition-all"
              >
                Close
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default UserActivityDashboard;
