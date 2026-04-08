import axios from 'axios';

class ArticlesAPI {
  constructor() {
    this.baseUrl = '';
  }

  searchArticles(portalSlug, locale, query) {
    const encodedQuery = encodeURIComponent(query);
    let baseUrl = `${this.baseUrl}/hc/${portalSlug}/${locale}/articles.json?query=${encodedQuery}`;
    return axios.get(baseUrl);
  }
}

export default new ArticlesAPI();
