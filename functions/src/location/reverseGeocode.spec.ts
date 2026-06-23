import { describe, it, expect, vi, beforeEach } from 'vitest';
import axios from 'axios';
import { reverseGeocodeCoords } from './reverseGeocode';

vi.mock('axios');

const mockedAxios = axios as unknown as { get: ReturnType<typeof vi.fn> };

beforeEach(() => {
  mockedAxios.get.mockReset();
});

describe('reverseGeocodeCoords', () => {
  it('returns formatted_address on OK with results', async () => {
    mockedAxios.get.mockResolvedValue({
      data: { status: 'OK', results: [{ formatted_address: '123 Main St, Johannesburg, South Africa' }] },
    });
    const address = await reverseGeocodeCoords(-26.2041, 28.0473, 'test-key');
    expect(address).toBe('123 Main St, Johannesburg, South Africa');
  });

  it('returns empty string on ZERO_RESULTS', async () => {
    mockedAxios.get.mockResolvedValue({ data: { status: 'ZERO_RESULTS', results: [] } });
    const address = await reverseGeocodeCoords(0, 0, 'test-key');
    expect(address).toBe('');
  });

  it('returns empty string on OVER_QUERY_LIMIT', async () => {
    mockedAxios.get.mockResolvedValue({ data: { status: 'OVER_QUERY_LIMIT', results: [] } });
    const address = await reverseGeocodeCoords(-26.2041, 28.0473, 'test-key');
    expect(address).toBe('');
  });

  it('returns empty string on REQUEST_DENIED', async () => {
    mockedAxios.get.mockResolvedValue({ data: { status: 'REQUEST_DENIED', results: [] } });
    const address = await reverseGeocodeCoords(-26.2041, 28.0473, 'test-key');
    expect(address).toBe('');
  });

  it('returns empty string when axios throws', async () => {
    mockedAxios.get.mockRejectedValue(new Error('network down'));
    const address = await reverseGeocodeCoords(-26.2041, 28.0473, 'test-key');
    expect(address).toBe('');
  });

  it('returns empty string and does not call axios when apiKey is empty', async () => {
    const address = await reverseGeocodeCoords(-26.2041, 28.0473, '');
    expect(address).toBe('');
    expect(mockedAxios.get).not.toHaveBeenCalled();
  });
});
