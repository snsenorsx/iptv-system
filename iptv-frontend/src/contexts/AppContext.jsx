import React, { createContext, useContext, useReducer, useEffect } from 'react';
import api from '../lib/api';

// Initial state
const initialState = {
  categories: [],
  channels: [],
  currentChannel: null,
  continueWatching: [],
  searchResults: [],
  loading: false,
  error: null
};

// Action types
const actionTypes = {
  SET_LOADING: 'SET_LOADING',
  SET_ERROR: 'SET_ERROR',
  SET_CATEGORIES: 'SET_CATEGORIES',
  SET_CHANNELS: 'SET_CHANNELS',
  SET_CURRENT_CHANNEL: 'SET_CURRENT_CHANNEL',
  SET_CONTINUE_WATCHING: 'SET_CONTINUE_WATCHING',
  SET_SEARCH_RESULTS: 'SET_SEARCH_RESULTS',
  UPDATE_WATCH_POSITION: 'UPDATE_WATCH_POSITION'
};

// Reducer
function appReducer(state, action) {
  switch (action.type) {
    case actionTypes.SET_LOADING:
      return { ...state, loading: action.payload };
    
    case actionTypes.SET_ERROR:
      return { ...state, error: action.payload, loading: false };
    
    case actionTypes.SET_CATEGORIES:
      return { ...state, categories: action.payload };
    
    case actionTypes.SET_CHANNELS:
      return { ...state, channels: action.payload };
    
    case actionTypes.SET_CURRENT_CHANNEL:
      return { ...state, currentChannel: action.payload };
    
    case actionTypes.SET_CONTINUE_WATCHING:
      return { ...state, continueWatching: action.payload };
    
    case actionTypes.SET_SEARCH_RESULTS:
      return { ...state, searchResults: action.payload };
    
    case actionTypes.UPDATE_WATCH_POSITION:
      return {
        ...state,
        continueWatching: state.continueWatching.map(item =>
          item.channel_id === action.payload.channelId
            ? { ...item, watch_position: action.payload.position }
            : item
        )
      };
    
    default:
      return state;
  }
}

// Context
const AppContext = createContext();

// Provider component
export function AppProvider({ children }) {
  const [state, dispatch] = useReducer(appReducer, initialState);

  // Actions
  const actions = {
    setLoading: (loading) => dispatch({ type: actionTypes.SET_LOADING, payload: loading }),
    setError: (error) => dispatch({ type: actionTypes.SET_ERROR, payload: error }),
    setCategories: (categories) => dispatch({ type: actionTypes.SET_CATEGORIES, payload: categories }),
    setChannels: (channels) => dispatch({ type: actionTypes.SET_CHANNELS, payload: channels }),
    setCurrentChannel: (channel) => dispatch({ type: actionTypes.SET_CURRENT_CHANNEL, payload: channel }),
    setContinueWatching: (items) => dispatch({ type: actionTypes.SET_CONTINUE_WATCHING, payload: items }),
    setSearchResults: (results) => dispatch({ type: actionTypes.SET_SEARCH_RESULTS, payload: results }),
    
    updateWatchPosition: async (channelId, position) => {
      try {
        await api.updateWatchPosition(channelId, position);
        dispatch({ 
          type: actionTypes.UPDATE_WATCH_POSITION, 
          payload: { channelId, position } 
        });
      } catch (error) {
        console.error('İzleme pozisyonu güncellenemedi:', error);
      }
    },

    loadContinueWatching: async (sessionId = 'default') => {
      try {
        actions.setLoading(true);
        const response = await api.getContinueWatching(sessionId);
        if (response.success) {
          actions.setContinueWatching(response.continue_watching);
        }
      } catch (error) {
        actions.setError('Kaldığı yerden devam listesi yüklenemedi');
      } finally {
        actions.setLoading(false);
      }
    }
  };

  // Context value
  const value = {
    ...state,
    actions,
    api
  };

  return (
    <AppContext.Provider value={value}>
      {children}
    </AppContext.Provider>
  );
}

// Hook
export function useApp() {
  const context = useContext(AppContext);
  if (!context) {
    throw new Error('useApp must be used within an AppProvider');
  }
  return context;
}

