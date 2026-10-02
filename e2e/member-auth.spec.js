const {test,expect}=require('@playwright/test');
for(const width of [360,1280]) test(`member screens fit ${width}px`,async({page})=>{
 await page.setViewportSize({width,height:844});
 for(const path of ['/uye-girisi','/uye-ol','/parolami-unuttum']){
  const response=await page.goto(path);expect(response.status()).toBe(200);
  await expect(page.locator('h2')).toBeVisible();
  expect(await page.evaluate(()=>document.documentElement.scrollWidth-innerWidth)).toBeLessThanOrEqual(1);
 }
});
test('registration proceeds to email code and prevents invalid form submission',async({page})=>{
 await page.goto('/uye-ol');
 await page.route('**/api/public/membership/register*',r=>r.fulfill({json:{status:'accepted'}}));
 await page.getByRole('button',{name:'Hesap oluştur'}).click();await expect(page.locator('[name=name]')).toBeVisible();
 await page.locator('[name=name]').fill('Test Customer');await page.locator('[name=email]').fill('customer@example.test');
 await page.locator('[name=phone]').fill('+905551234567');await page.locator('[name=password]').fill('example-long-password');
 await page.locator('[name=terms]').check();await page.getByRole('button',{name:'Hesap oluştur'}).click();
 await expect(page.locator('[name=code]')).toBeVisible();
});
test('reset requests reset-purpose code and unauthenticated requests require CSRF',async({page,request})=>{
 await page.goto('/parolami-unuttum');let purpose;
 await page.route('**/api/public/membership/request*',r=>{purpose=new URLSearchParams(r.request().postData()).get('purpose');return r.fulfill({json:{status:'accepted'}});});
 await page.locator('[name=email]').fill('customer@example.test');await page.locator('button.primary').click();
 await expect(page.locator('[name=code]')).toBeVisible();expect(purpose).toBe('reset');
 await expect(page.locator('[name=password]')).toBeVisible();
 const r=await request.post('/api/public/membership/register',{form:{email:'x@example.test'}});expect(r.status()).toBe(403);
});
