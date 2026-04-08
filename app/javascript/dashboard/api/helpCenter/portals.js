/* global axios */
import ApiClient from '../ApiClient';

const buildPortalPayload = (portalObj = {}) => {
  const payload = { portal: portalObj };

  if (Object.prototype.hasOwnProperty.call(portalObj, 'blob_id')) {
    payload.blob_id = portalObj.blob_id;
  }
  if (Object.prototype.hasOwnProperty.call(portalObj, 'inbox_id')) {
    payload.inbox_id = portalObj.inbox_id;
  }

  return payload;
};

class PortalsAPI extends ApiClient {
  constructor() {
    super('portals', { accountScoped: true });
  }

  create(portalObj) {
    return axios.post(this.url, buildPortalPayload(portalObj));
  }

  getPortal({ portalSlug, locale }) {
    return axios.get(`${this.url}/${portalSlug}?locale=${locale}`);
  }

  updatePortal({ portalSlug, portalObj }) {
    return axios.patch(
      `${this.url}/${portalSlug}`,
      buildPortalPayload(portalObj)
    );
  }

  deletePortal(portalSlug) {
    return axios.delete(`${this.url}/${portalSlug}`);
  }

  deleteLogo(portalSlug) {
    return axios.delete(`${this.url}/${portalSlug}/logo`);
  }

  sendCnameInstructions(portalSlug, email) {
    return axios.post(`${this.url}/${portalSlug}/send_instructions`, { email });
  }

  sslStatus(portalSlug) {
    return axios.get(`${this.url}/${portalSlug}/ssl_status`);
  }
}

export default PortalsAPI;
