export default function EmailConfirmed() {
  return (
    <div className="min-h-screen bg-[#1A1C20] flex items-center justify-center px-4">
      <div className="bg-[#23252A] rounded-2xl border border-[#2D2F34] p-10 max-w-md w-full text-center">
        {/* Success icon */}
        <div className="mx-auto w-20 h-20 rounded-full bg-[#2A9D8F]/15 flex items-center justify-center mb-6">
          <svg className="w-10 h-10 text-[#2A9D8F]" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2.5} d="M5 13l4 4L19 7" />
          </svg>
        </div>

        {/* Logo */}
        <img src="/icon.png" alt="SugoBay" className="w-16 h-16 rounded-full mx-auto mb-3 shadow-lg" />
        <h1 className="text-2xl font-bold text-white mb-2">SugoBay</h1>
        <p className="text-gray-500 text-sm mb-6">Sugo para sa tanan sa Ubay</p>

        {/* Message */}
        <div className="bg-[#2A9D8F]/10 border border-[#2A9D8F]/30 rounded-xl p-5 mb-6">
          <h2 className="text-[#2A9D8F] text-lg font-semibold mb-2">Email Confirmed!</h2>
          <p className="text-gray-400 text-sm leading-relaxed">
            Your email has been successfully verified. You can now log in to the SugoBay app.
          </p>
        </div>

        {/* Instructions */}
        <div className="text-gray-500 text-sm space-y-3">
          <p>Open the <span className="text-white font-medium">SugoBay</span> app on your phone and sign in with your email and password.</p>
        </div>

        {/* Decorative footer */}
        <div className="mt-8 pt-6 border-t border-[#2D2F34]">
          <p className="text-gray-600 text-xs">You can close this page now.</p>
        </div>
      </div>
    </div>
  )
}
