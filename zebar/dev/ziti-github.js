export const GITHUB_USER = "CLBRITTON2";
export const GITHUB_ORGS = "org:openziti org:netfoundry";

export const ZITI_SECTIONS = [
  { key: "prs", title: "Pull requests", query: `${GITHUB_ORGS} is:open is:pr author:${GITHUB_USER}`, type: "pullrequests" },
  { key: "issues", title: "Issues", query: `${GITHUB_ORGS} is:open is:issue author:${GITHUB_USER}`, type: "issues" },
  { key: "assigned", title: "Assigned to me", query: `${GITHUB_ORGS} is:open is:issue assignee:${GITHUB_USER} -author:${GITHUB_USER}`, type: "issues" },
];

export function sectionSearchUrl(section) {
  return `https://github.com/search?q=${encodeURIComponent(section.query)}&type=${section.type}`;
}

export async function fetchSectionItems(section) {
  const res = await fetch(`https://api.github.com/search/issues?q=${encodeURIComponent(section.query)}&per_page=100`);
  if (!res.ok) throw new Error(`GitHub search ${res.status} for ${section.key}`);
  const data = await res.json();
  return data.items;
}
