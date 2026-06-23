import functions from '@react-native-firebase/functions';
import { reverseGeocode } from './locationRepository';

jest.mock('@react-native-firebase/functions');

const mockCallable = jest.fn();

beforeEach(() => {
  mockCallable.mockReset();
  (functions().httpsCallable as jest.Mock).mockReturnValue(mockCallable);
});

describe('reverseGeocode', () => {
  it('returns the address string on success and forwards lat/lng', async () => {
    mockCallable.mockResolvedValue({ data: { address: '123 Main St, Johannesburg' } });
    const address = await reverseGeocode(-26.2041, 28.0473);
    expect(address).toBe('123 Main St, Johannesburg');
    expect(mockCallable).toHaveBeenCalledWith({ latitude: -26.2041, longitude: 28.0473 });
  });

  it('returns empty string when the callable throws', async () => {
    mockCallable.mockRejectedValue(new Error('unavailable'));
    const address = await reverseGeocode(-26.2041, 28.0473);
    expect(address).toBe('');
  });

  it('returns empty string when address is missing from the response', async () => {
    mockCallable.mockResolvedValue({ data: {} });
    const address = await reverseGeocode(-26.2041, 28.0473);
    expect(address).toBe('');
  });
});