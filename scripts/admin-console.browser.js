// Run against a local static preview with playwright-cli run-code --filename=... .
// Browser-only fixtures: API requests are intercepted; production data stays unchanged.
async page => {
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  const names = ['users','course_notes','user_courses','study_workspaces','course_review_cards','course_artifacts','campus_content','forge_repositories','forge_discussions','forge_replies','forge_stars','user_favorites'];
  const schemas = names.map(name => ({ id:name, name, type:name === 'users' ? 'auth' : 'base', fields:[{name:'id',type:'text'},{name:'name',type:'text'},{name:'owner',type:'relation'},{name:'title',type:'text'},{name:'updated',type:'autodate'}] }));
  const user = {id:'0123456789abcde',name:'验收用户',email:'ui-test@example.com',verified:true};
  const project = {id:'abcdefghijklmno',name:'校园协作工具',owner:user.id,reviewState:'pending',schoolProof:'华东师范大学项目归属材料',universityId:'ecnu',visibility:'public',expand:{owner:user}};
  await page.route('**/api/**', async route => {
    const path = route.request().url().replace(/^https?:\/\/[^/]+/, '').split('?')[0];
    let body;
    if (path.endsWith('/auth-with-password')) body = {token:'browser-fixture-token'};
    else if (path === '/api/collections') body = {items:schemas,totalPages:1};
    else if (path.endsWith('/' + project.id)) body = project;
    else {
      const items = path.includes('/users/') ? [user] : path.includes('/forge_repositories/') ? [project] : [];
      body = {items,totalItems:items.length,totalPages:1,page:1};
    }
    await route.fulfill({json:body});
  });
  const check = (condition, message) => { if (!condition) throw new Error(message); };
  await page.setViewportSize({width:1440,height:1000});
  await page.emulateMedia({reducedMotion:'reduce'});
  await page.reload();
  await page.locator('[name=email]').fill('ui-test@example.com');
  await page.locator('[name=password]').fill('browser-fixture-password');
  await page.locator('#login-form button').click();
  await page.locator('#dashboard').waitFor({state:'visible'});
  await page.waitForFunction(() => !document.body.classList.contains('busy'));
  check(await page.locator('#sections svg').count() >= 20, 'Sidebar icons');
  const layout = await page.evaluate(() => {
    const sidebar = document.querySelector('#sidebar').getBoundingClientRect(), workspace = document.querySelector('#workspace').getBoundingClientRect();
    return {left:sidebar.left,width:sidebar.width,content:workspace.left,overflow:document.documentElement.scrollWidth > innerWidth};
  });
  check(layout.left === 0 && layout.width > 200 && layout.content >= layout.width && !layout.overflow, 'Desktop two-column layout');
  await page.screenshot({path:'.tools/admin-console-desktop.png',fullPage:true});
  await page.locator('#rows').getByRole('button',{name:'打开工作区'}).click();
  await page.waitForFunction(() => !document.body.classList.contains('busy'));
  check((await page.locator('#user-context').textContent()).includes('验收用户'), 'User context');
  await page.locator('#sections details').filter({has:page.locator('summary[data-label="课程"]')}).first().evaluate(node => { node.open = true; });
  await page.locator('[data-view=notes]').click();
  await page.waitForFunction(() => !document.body.classList.contains('busy'));
  check((await page.locator('#breadcrumbs').textContent()).includes('课程笔记'), 'Nested breadcrumb');
  await page.locator('summary[data-label="公共内容与审核"]').click();
  await page.locator('[data-view=reviews]').click();
  await page.waitForFunction(() => !document.body.classList.contains('busy'));
  await page.locator('#rows').getByRole('button',{name:'审核申请'}).click();
  await page.locator('#review-dialog').waitFor({state:'visible'});
  check((await page.locator('#review-material').textContent()).includes('华东师范大学'), 'Review materials');
  await page.screenshot({path:'.tools/admin-console-review.png'});
  await page.locator('#cancel-review').click();
  await page.setViewportSize({width:390,height:844});
  check(!(await page.locator('#sidebar').isVisible()), 'Mobile sidebar starts collapsed');
  await page.locator('#sidebar-toggle').click();
  check(await page.locator('#sidebar').isVisible(), 'Mobile sidebar expands');
  await page.screenshot({path:'.tools/admin-console-mobile-navigation.png',fullPage:true});
  await page.keyboard.press('Escape');
  check(!(await page.locator('#sidebar').isVisible()), 'Escape closes mobile sidebar');
  check(await page.locator('#sidebar-toggle').evaluate(node => node === document.activeElement), 'Escape restores focus');
  check(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), 'Mobile page overflow');
  await page.screenshot({path:'.tools/admin-console-mobile.png',fullPage:true});
  await page.emulateMedia({reducedMotion:'reduce'});
  check(await page.locator('.workspace-body').evaluate(node => getComputedStyle(node).animationName === 'none'), 'Reduced motion');
  await page.locator('#logout').click();
  check(await page.locator('#login').isVisible(), 'Logout');
  check(errors.length === 0, errors.join('\n'));
  return {checks:14,passed:true,desktop:layout,errors};
}
