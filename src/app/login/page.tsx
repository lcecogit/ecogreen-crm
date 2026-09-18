import { BrandPhoto } from "@/components/media/BrandPhoto";
import { brand, photos } from "@/lib/brand-content";

import { SignInForm } from "./SignInForm";

export const metadata = { title: "Sign in" };

/** A two-panel sign-in: the form on the left, the brand's photography on the
 *  right. This is one of only three surfaces where a photograph is allowed
 *  (DESIGN.md §6), and the layout is what stops the form floating alone in a
 *  large empty field.
 *
 *  The image panel is decorative, so it is hidden below the large breakpoint
 *  rather than stacked — on a phone it would push the form below the fold for
 *  no gain. */
export default function LoginPage() {
  return (
    <div className="grid min-h-dvh lg:grid-cols-2">
      <main id="main" className="flex items-center justify-center px-4 py-14 sm:px-8">
        <div className="w-full max-w-sm">
          <h1 className="text-title-1">Sign in</h1>
          <p className="mt-2 text-body text-ink-2 text-balance">
            Staff accounts are created by invitation. If you don&rsquo;t have one, ask your manager.
          </p>
          <div className="mt-8">
            <SignInForm />
          </div>
          <p className="mt-10 text-caption text-ink-3">
            {brand.name} operations platform. Internal use only.
          </p>
          {/* A standalone link is a control, not prose, so it gets a real
              44px target rather than the height of its text. */}
          <a
            href="/"
            className="-ml-1 inline-flex h-11 items-center px-1 text-caption text-ink-2 underline-offset-4 hover:text-ink-1 hover:underline"
          >
            ← Back to the website
          </a>
        </div>
      </main>

      <BrandPhoto
        className="hidden lg:block"
        src={photos.signIn.src}
        alt={photos.signIn.alt}
        sizes="50vw"
        priority
      />
    </div>
  );
}
