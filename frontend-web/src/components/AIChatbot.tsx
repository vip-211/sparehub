import React, { useState, useRef, useEffect } from 'react';
import api, { API_BASE_URL } from '../services/api';
import { MessageSquare, Send, X, Bot, User, Loader2, ThumbsUp, ThumbsDown, Edit3 } from 'lucide-react';
import { Image as ImageIcon, Mic } from 'lucide-react';
import { useCart } from '../context/CartContext';
import { useNavigate } from 'react-router-dom';

interface Message {
  text: string;
  isBot: boolean;
  prompt?: string;
}

const AIChatbot: React.FC = () => {
  const [isOpen, setIsOpen] = useState(false);
  const [messages, setMessages] = useState<Message[]>([
    { text: "Hello! I'm your Parts Mitra AI assistant. How can I help you today?", isBot: true }
  ]);
  const [input, setInput] = useState('');
  const [loading, setLoading] = useState(false);
  const imageInputRef = useRef<HTMLInputElement>(null);
  const audioInputRef = useRef<HTMLInputElement>(null);
  const messagesEndRef = useRef<HTMLDivElement>(null);
  const [matches, setMatches] = useState<any[]>([]);
  const [isTrainingOpen, setIsTrainingOpen] = useState(false);
  const [trainingPrompt, setTrainingPrompt] = useState('');
  const [originalResponse, setOriginalResponse] = useState('');
  const [correction, setCorrection] = useState('');
  const [aiProvider, setAiProvider] = useState('gemini');
  const [isAiEnabled, setIsAiEnabled] = useState(true);
  const cart = useCart();
  const navigate = useNavigate();

  useEffect(() => {
    const fetchSettings = async () => {
      try {
        const res = await api.get('settings/public');
        const settings = res.data || [];
        const providerSetting = settings.find((s: any) => s.settingKey === 'AI_PROVIDER');
        const enabledSetting = settings.find((s: any) => s.settingKey === 'AI_CHATBOT_ENABLED');
        
        if (providerSetting) setAiProvider(providerSetting.settingValue);
        if (enabledSetting) setIsAiEnabled(enabledSetting.settingValue === 'true');
      } catch (e) {
        console.error('Error fetching AI settings', e);
      }
    };
    fetchSettings();
  }, []);

  const handleFeedback = async (prompt: string, response: string, isPositive: boolean) => {
    try {
      await api.post('ai/feedback', { prompt, response, isPositive, timestamp: new Date().toISOString() });
      // In a real app, you might show a small toast/notification here
    } catch (error) {
      console.error('Feedback Error:', error);
    }
  };

  const handleTrainSubmit = async () => {
    if (!correction.trim() || correction === originalResponse) return;
    try {
      await api.post('ai/train', {
        prompt: trainingPrompt,
        originalResponse: originalResponse,
        correctedResponse: correction,
        timestamp: new Date().toISOString(),
      });
      setIsTrainingOpen(false);
      setCorrection('');
    } catch (error) {
      console.error('Training Error:', error);
    }
  };

  const getImageUrl = (path: string) => {
    if (!path) return '';
    if (path.startsWith('http')) return path;
    const base = API_BASE_URL.endsWith('/api') ? API_BASE_URL.replace('/api', '') : API_BASE_URL;
    return `${base}${path.startsWith('/') ? '' : '/'}${path}`;
  };

  const scrollToBottom = () => {
    messagesEndRef.current?.scrollIntoView({ behavior: "smooth" });
  };

  useEffect(() => {
    scrollToBottom();
  }, [messages]);

  const handleSend = async () => {
    if (!input.trim()) return;

    const userMessage = { text: input, isBot: false };
    setMessages(prev => [...prev, userMessage]);
    setInput('');
    setLoading(true);

    try {
      const res = await api.post('ai/chat', { prompt: input }, { headers: { 'X-AI-Provider': aiProvider } });
      const botMessage = { text: res.data.response, isBot: true, prompt: input };
      setMessages(prev => [...prev, botMessage]);
    } catch (error) {
      console.error('AI Chat Error:', error);
      const errorMessage = { text: "Sorry, I'm having trouble connecting to my brain right now.", isBot: true, prompt: input };
      setMessages(prev => [...prev, errorMessage]);
    } finally {
      setLoading(false);
    }
  };

  const fetchMatches = async (query: string) => {
    try {
      const res = await api.get('products/search', { params: { query } });
      setMatches(res.data || []);
    } catch (e) {
      console.error('Product search error', e);
      setMatches([]);
    }
  };

  const handleUploadImage = async (file: File) => {
    setLoading(true);
    try {
      const form = new FormData();
      form.append('image', file);
      const res = await api.post('ai/search/photo', form, {
        headers: { 'Content-Type': 'multipart/form-data', 'X-AI-Provider': 'gemini' },
      });
      const botMessage = { text: res.data.response, isBot: true, prompt: `Search by photo: ${file.name}` };
      setMessages(prev => [...prev, botMessage]);
      await fetchMatches(res.data.response);
    } catch (error) {
      console.error('AI Photo Search Error:', error);
      setMessages(prev => [...prev, { text: 'Failed to analyze image.', isBot: true, prompt: 'Search by photo' }]);
    } finally {
      setLoading(false);
    }
  };

  const handleUploadAudio = async (file: File) => {
    setLoading(true);
    try {
      const form = new FormData();
      form.append('audio', file);
      const res = await api.post('ai/search/voice', form, {
        headers: { 'Content-Type': 'multipart/form-data', 'X-AI-Provider': 'gemini' },
      });
      const botMessage = { text: res.data.response, isBot: true, prompt: `Search by voice: ${file.name}` };
      setMessages(prev => [...prev, botMessage]);
      await fetchMatches(res.data.response);
    } catch (error) {
      console.error('AI Voice Search Error:', error);
      setMessages(prev => [...prev, { text: 'Failed to process audio.', isBot: true, prompt: 'Search by voice' }]);
    } finally {
      setLoading(false);
    }
  };

  if (!isAiEnabled) return null;

  return (
    <div className="fixed bottom-6 right-6 z-[100]">
      {isOpen ? (
        <div className="bg-white rounded-3xl shadow-2xl border border-gray-100 w-[340px] md:w-[400px] flex flex-col h-[550px] overflow-hidden transition-all duration-500 animate-in slide-in-from-bottom-12">
          {/* Header */}
          <div className="bg-gradient-to-br from-blue-600 to-blue-500 p-5 flex items-center justify-between text-white shadow-lg relative overflow-hidden">
            <div className="absolute top-0 right-0 p-4 opacity-10">
              <Bot size={80} />
            </div>
            <div className="flex items-center gap-3 relative z-10">
              <div className="bg-white/20 p-2 rounded-xl backdrop-blur-sm">
                <Bot className="w-6 h-6" />
              </div>
              <div>
                <h3 className="font-bold text-lg leading-tight">Parts Mitra AI</h3>
                <p className="text-blue-100 text-[10px] font-medium uppercase tracking-widest flex items-center gap-1.5">
                  <span className="w-2 h-2 bg-blue-400 rounded-full animate-pulse"></span>
                  Always Active
                </p>
              </div>
            </div>
            <button 
              onClick={(e) => {
                e.preventDefault();
                e.stopPropagation();
                setIsOpen(false);
              }} 
              className="hover:bg-white/20 p-2.5 rounded-2xl transition-all duration-300 active:scale-75 z-20 group/close cursor-pointer"
              aria-label="Close Chat"
            >
              <X className="w-6 h-6 text-white group-hover/close:rotate-90 transition-transform duration-300" />
            </button>
          </div>

          {/* Messages */}
          <div className="flex-grow p-5 overflow-y-auto space-y-5 bg-slate-50/50">
            {messages.map((msg, idx) => (
              <div key={idx} className={`flex flex-col ${msg.isBot ? 'items-start' : 'items-end'} animate-in fade-in slide-in-from-bottom-2 duration-300`}>
                <div className={`max-w-[85%] p-4 rounded-2xl text-[13px] leading-relaxed shadow-sm transition-all ${
                  msg.isBot 
                    ? 'bg-white border border-gray-100 text-slate-700 rounded-tl-none ring-1 ring-black/5' 
                    : 'bg-blue-600 text-white rounded-tr-none shadow-blue-200 shadow-md'
                }`}>
                  <div className={`flex items-center gap-1.5 mb-1.5 opacity-50 text-[9px] font-bold uppercase tracking-wider ${msg.isBot ? 'text-blue-600' : 'text-blue-50'}`}>
                    {msg.isBot ? <Bot className="w-3 h-3" /> : <User className="w-3 h-3" />}
                    {msg.isBot ? 'Assistant' : 'You'}
                  </div>
                  {msg.text}
                </div>
                {msg.isBot && idx > 0 && (
                  <div className="flex items-center gap-2 mt-2 ml-1">
                    <button 
                      onClick={() => handleFeedback(msg.prompt || 'N/A', msg.text, true)}
                      className="p-1.5 rounded-lg hover:bg-slate-200 text-slate-400 hover:text-blue-600 transition-all"
                      title="Helpful"
                    >
                      <ThumbsUp size={14} />
                    </button>
                    <button 
                      onClick={() => handleFeedback(msg.prompt || 'N/A', msg.text, false)}
                      className="p-1.5 rounded-lg hover:bg-slate-200 text-slate-400 hover:text-red-500 transition-all"
                      title="Not helpful"
                    >
                      <ThumbsDown size={14} />
                    </button>
                    <button 
                      onClick={() => {
                        setTrainingPrompt(msg.prompt || 'N/A');
                        setOriginalResponse(msg.text);
                        setCorrection(msg.text);
                        setIsTrainingOpen(true);
                      }}
                      className="flex items-center gap-1 px-2 py-1 rounded-lg hover:bg-slate-200 text-slate-400 hover:text-slate-600 transition-all text-[10px] font-bold uppercase tracking-wider"
                    >
                      <Edit3 size={12} />
                      Train AI
                    </button>
                  </div>
                )}
              </div>
            ))}
            {loading && (
              <div className="flex justify-start animate-pulse">
                <div className="bg-white border border-gray-100 p-4 rounded-2xl rounded-tl-none shadow-sm ring-1 ring-black/5 flex items-center gap-3">
                  <div className="flex gap-1">
                    <span className="w-1.5 h-1.5 bg-blue-400 rounded-full animate-bounce"></span>
                    <span className="w-1.5 h-1.5 bg-blue-400 rounded-full animate-bounce [animation-delay:0.2s]"></span>
                    <span className="w-1.5 h-1.5 bg-blue-400 rounded-full animate-bounce [animation-delay:0.4s]"></span>
                  </div>
                  <span className="text-[11px] text-slate-400 font-medium tracking-tight">AI is crafting a response...</span>
                </div>
              </div>
            )}
            <div ref={messagesEndRef} />
          </div>

          {/* Input */}
          <div className="p-5 bg-white border-t border-slate-100">
            <div className="flex items-center gap-2 bg-slate-50 p-1.5 rounded-2xl border border-slate-200 focus-within:border-blue-400 focus-within:ring-4 focus-within:ring-blue-50 transition-all duration-300">
              <input
                type="text"
                value={input}
                onChange={(e) => setInput(e.target.value)}
                onKeyPress={(e) => e.key === 'Enter' && handleSend()}
                placeholder="How can I help you today?"
                className="flex-grow bg-transparent border-none focus:outline-none text-sm px-3 py-2 text-slate-700 placeholder:text-slate-400"
                disabled={loading}
              />
              <input
                type="file"
                accept="image/*"
                ref={imageInputRef}
                className="hidden"
                onChange={(e) => {
                  const file = e.target.files?.[0];
                  if (file) {
                    setMessages(prev => [...prev, { text: 'Analyzing image...', isBot: true }]);
                    handleUploadImage(file);
                    e.currentTarget.value = '';
                  }
                }}
              />
              <button
                onClick={() => imageInputRef.current?.click()}
                disabled={loading}
                className="p-2.5 rounded-xl bg-slate-200 text-slate-700 hover:bg-slate-300 transition-all"
                title="Search by photo"
              >
                <ImageIcon className="w-4 h-4" />
              </button>
              <input
                type="file"
                accept="audio/*"
                ref={audioInputRef}
                className="hidden"
                onChange={(e) => {
                  const file = e.target.files?.[0];
                  if (file) {
                    setMessages(prev => [...prev, { text: 'Processing audio query...', isBot: true }]);
                    handleUploadAudio(file);
                    e.currentTarget.value = '';
                  }
                }}
              />
              <button
                onClick={() => audioInputRef.current?.click()}
                disabled={loading}
                className="p-2.5 rounded-xl bg-slate-200 text-slate-700 hover:bg-slate-300 transition-all"
                title="Search by voice"
              >
                <Mic className="w-4 h-4" />
              </button>
              <button 
                onClick={handleSend}
                disabled={loading || !input.trim()}
                className={`p-2.5 rounded-xl transition-all duration-300 active:scale-95 ${
                  input.trim() ? 'bg-blue-600 text-white shadow-lg shadow-blue-200 hover:bg-blue-700' : 'bg-slate-200 text-slate-400'
                }`}
              >
                <Send className="w-4 h-4" />
              </button>
            </div>
            {matches.length > 0 && (
              <div className="mt-4 bg-white border border-gray-100 rounded-2xl p-4">
                <div className="font-bold text-gray-900 mb-3">Matched Products</div>
                <div className="grid grid-cols-1 gap-3">
                  {matches.slice(0, 6).map((p) => {
                    const displayPrice = p.sellingPrice ?? p.mrp ?? 0;
                    return (
                      <div key={p.id} className="flex items-center gap-3 p-3 border border-gray-100 rounded-xl">
                        <div className="w-12 h-12 rounded-lg bg-gray-50 flex items-center justify-center border border-gray-100 overflow-hidden">
                          {p.imagePath || p.imageLink || p.categoryImageLink || p.categoryImagePath ? (
                            <img src={getImageUrl(p.imagePath || p.imageLink || p.categoryImageLink || p.categoryImagePath)} alt={p.name} className="w-12 h-12 object-cover" />
                          ) : (
                            <Bot className="w-6 h-6 text-gray-300" />
                          )}
                        </div>
                        <div className="flex-grow">
                          <div className="font-bold text-gray-900">{p.name}</div>
                          <div className="text-xs font-bold text-gray-400 uppercase tracking-widest">Part: {p.partNumber}</div>
                        </div>
                        <div className="text-primary-700 font-black">₹{displayPrice}</div>
                        <div className="flex gap-2">
                          <button
                            onClick={() => cart.addItem({ productId: p.id, name: p.name, price: displayPrice, partNumber: p.partNumber })}
                            className="px-3 py-1.5 bg-primary-50 text-primary-700 rounded-lg text-xs font-bold hover:bg-primary-100"
                          >
                            Add
                          </button>
                          <button
                            onClick={async () => {
                              try {
                                const res = await api.post('ai/order', { productId: p.id, quantity: 1 });
                                const msg = `Order placed: #${res.data.orderId} • ₹${res.data.total}`;
                                setMessages(prev => [...prev, { text: msg, isBot: true }]);
                              } catch (e) {
                                setMessages(prev => [...prev, { text: 'Failed to place order.', isBot: true }]);
                              }
                            }}
                            className="px-3 py-1.5 bg-blue-50 text-blue-700 rounded-lg text-xs font-bold hover:bg-blue-100"
                          >
                            Order
                          </button>
                          <button
                            onClick={() => navigate(`/shop?q=${encodeURIComponent(p.name)}`)}
                            className="px-3 py-1.5 bg-gray-50 text-gray-700 rounded-lg text-xs font-bold hover:bg-gray-100"
                          >
                            View
                          </button>
                        </div>
                      </div>
                    );
                  })}
                </div>
              </div>
            )}
            <p className="text-center text-[9px] text-slate-400 mt-3 font-medium uppercase tracking-tighter">Powered by Parts Mitra AI Engine</p>
          </div>
        </div>
      ) : (
        <div className="flex flex-col items-end gap-3 group">
          <div className="bg-slate-900 text-white text-[11px] font-bold px-4 py-2.5 rounded-2xl opacity-0 translate-y-2 group-hover:opacity-100 group-hover:translate-y-0 transition-all duration-300 shadow-2xl pointer-events-none relative mb-1">
            Need help with parts? Ask AI
            <div className="absolute bottom-[-6px] right-6 w-3 h-3 bg-slate-900 rotate-45"></div>
          </div>
          <button
            onClick={() => setIsOpen(true)}
            className="bg-gradient-to-br from-blue-600 to-blue-500 text-white p-5 rounded-3xl shadow-2xl hover:shadow-blue-200/50 hover:scale-110 transition-all duration-500 active:scale-95 relative"
          >
            <MessageSquare className="w-7 h-7" />
            <span className="absolute -top-1 -right-1 w-4 h-4 bg-blue-500 border-2 border-white rounded-full"></span>
          </button>
        </div>
      )}

      {/* Training Modal */}
      {isTrainingOpen && (
        <div className="fixed inset-0 z-[200] flex items-center justify-center p-4 bg-black/50 backdrop-blur-sm animate-in fade-in duration-300">
          <div className="bg-white rounded-3xl shadow-2xl w-full max-w-md overflow-hidden animate-in zoom-in-95 duration-300">
            <div className="p-6 border-b border-slate-100 flex items-center justify-between">
              <h3 className="font-bold text-xl text-slate-800">Train AI</h3>
              <button onClick={() => setIsTrainingOpen(false)} className="p-2 hover:bg-slate-100 rounded-xl transition-all">
                <X size={20} className="text-slate-400" />
              </button>
            </div>
            <div className="p-6 space-y-4">
              <p className="text-sm text-slate-500 leading-relaxed">
                Help us improve! What should have been the correct response for this query?
              </p>
              <div className="bg-slate-50 p-4 rounded-2xl border border-slate-100">
                <div className="text-[10px] font-bold text-slate-400 uppercase tracking-widest mb-1">Prompt</div>
                <div className="text-xs text-slate-600 italic">"{trainingPrompt}"</div>
              </div>
              <textarea
                value={correction}
                onChange={(e) => setCorrection(e.target.value)}
                placeholder="Enter the correct response..."
                className="w-full h-32 p-4 bg-slate-50 border border-slate-200 rounded-2xl focus:outline-none focus:ring-4 focus:ring-blue-50 focus:border-blue-400 transition-all text-sm text-slate-700 placeholder:text-slate-400 resize-none"
              />
            </div>
            <div className="p-6 bg-slate-50/50 flex gap-3">
              <button 
                onClick={() => setIsTrainingOpen(false)}
                className="flex-grow py-3 px-4 bg-white border border-slate-200 text-slate-600 rounded-2xl font-bold text-sm hover:bg-slate-100 transition-all active:scale-95"
              >
                Cancel
              </button>
              <button 
                onClick={handleTrainSubmit}
                disabled={!correction.trim() || correction === originalResponse}
                className="flex-grow py-3 px-4 bg-blue-600 text-white rounded-2xl font-bold text-sm shadow-lg shadow-blue-200 hover:bg-blue-700 disabled:opacity-50 disabled:shadow-none transition-all active:scale-95"
              >
                Submit Correction
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default AIChatbot;
